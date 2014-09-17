// The MIT License
//
// Copyright (c) 2014 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "GRMustacheValidator_private.h"
#import "GRMustacheTemplateRepository_private.h"
#import "GRMustacheTemplateParser_private.h"
#import "GRMustacheCompiler_private.h"
#import "GRMustacheConfiguration_private.h"
#import "GRMustacheTemplateASTVisitor_private.h"
#import "GRMustacheExpression_private.h"
#import "GRMustacheExpressionVisitor_private.h"
#import "GRMustacheTemplateAST_private.h"
#import "GRMustacheInheritableSectionNode_private.h"
#import "GRMustacheVariableTag_private.h"
#import "GRMustacheSectionTag_private.h"
#import "GRMustacheFilteredExpression_private.h"
#import "GRMustacheIdentifierExpression_private.h"
#import "GRMustacheScopedExpression_private.h"
#import "GRMustacheImplicitIteratorExpression_private.h"
#import "GRMustacheToken_private.h"
#import "GRMustacheExpressionGenerator_private.h"
#import "GRMustacheExpressionParser_private.h"


NSString * const GRMustacheWarningDomain = @"GRMustacheWarningDomain";

GRMustacheWarnings const GRMustacheWarningAll = GRMustacheWarningGRMustacheDeprecationSlashInIdentifier|GRMustacheWarningGRMustacheUnsupportedPragma|GRMustacheWarningMustacheExtensionPragma|GRMustacheWarningMustacheExtensionFilter|GRMustacheWarningMustacheExtensionEmptyClosingTag|GRMustacheWarningMustacheExtensionImplicitClosingTag|GRMustacheWarningMustacheExtensionAnchoredExpression|GRMustacheWarningMustacheExtensionAbsolutePartialPath|GRMustacheWarningMustacheExtensionTemplateInheritance|GRMustacheWarningMustacheExtensionStandardLibrary;

@interface GRMustacheValidator()<GRMustacheTemplateASTVisitor, GRMustacheExpressionVisitor, GRMustacheTemplateParserDelegate>
@end

@implementation GRMustacheValidator

- (NSArray *)errorsAndWarningsForTemplateID:(id)templateID templateRepository:(GRMustacheTemplateRepository *)templateRepository
{
    NSError *error;
    NSString *templateString = [templateRepository.dataSource templateRepository:templateRepository templateStringForTemplateID:templateID error:&error];
    if (!templateString) {
        return @[error];
    }
    
    _errors = [[NSMutableArray alloc] init];
    
    _compiler = [[[GRMustacheCompiler alloc] initWithContentType:templateRepository.configuration.contentType] autorelease];
    _compiler.templateRepository = templateRepository;
    _compiler.baseTemplateID = templateID;
    
    GRMustacheTemplateParser *parser = [[[GRMustacheTemplateParser alloc] initWithConfiguration:templateRepository.configuration] autorelease];
    parser.delegate = self;
    
    [parser parseTemplateString:templateString templateID:templateID];
    GRMustacheTemplateAST *templateAST = [_compiler templateASTReturningError:&error];
    if (!templateAST) {
        return @[error];
    }
    
    _expressionGenerator = [[[GRMustacheExpressionGenerator alloc] init] autorelease];
    [self visitTemplateAST:templateAST error:NULL];
    return [_errors autorelease];
}


#pragma mark - GRMustacheTemplateASTVisitor

- (BOOL)visitTemplateAST:(GRMustacheTemplateAST *)templateAST error:(NSError **)error
{
    for (id<GRMustacheTemplateASTNode> node in templateAST.templateASTNodes) {
        [node acceptTemplateASTVisitor:self error:NULL];
    }
    return YES;
}

- (BOOL)visitInheritablePartialNode:(GRMustacheInheritablePartialNode *)inheritablePartialNode error:(NSError **)error
{
    return YES;
}

- (BOOL)visitInheritableSectionNode:(GRMustacheInheritableSectionNode *)inheritableSectionNode error:(NSError **)error
{
    [self visitTemplateAST:inheritableSectionNode.templateAST error:NULL];
    return YES;
}

- (BOOL)visitPartialNode:(GRMustachePartialNode *)partialNode error:(NSError **)error
{
    return YES;
}

- (BOOL)visitVariableTag:(GRMustacheVariableTag *)variableTag error:(NSError **)error
{
    [self validateExpression:variableTag.expression];
    
    GRMustacheTag *previousTag = _tag;
    _tag = variableTag;
    [variableTag.expression acceptVisitor:self error:NULL];
    _tag = previousTag;
    return YES;
}

- (BOOL)visitSectionTag:(GRMustacheSectionTag *)sectionTag error:(NSError **)error
{
    [self validateExpression:sectionTag.expression];
    
    GRMustacheTag *previousTag = _tag;
    _tag = sectionTag;
    [sectionTag.expression acceptVisitor:self error:NULL];
    _tag = previousTag;

    [self visitTemplateAST:sectionTag.templateAST error:NULL];
    return YES;
}

- (BOOL)visitTextNode:(GRMustacheTextNode *)textNode error:(NSError **)error
{
    return YES;
}



#pragma mark - GRMustacheExpressionVisitor

- (BOOL)visitFilteredExpression:(GRMustacheFilteredExpression *)expression error:(NSError **)error
{
    [self addWarningWithCode:GRMustacheWarningMustacheExtensionFilter token:expression.token];
    [expression.filterExpression acceptVisitor:self error:NULL];
    [expression.argumentExpression acceptVisitor:self error:NULL];
    return YES;
}

- (BOOL)visitIdentifierExpression:(GRMustacheIdentifierExpression *)expression error:(NSError **)error
{
    [self validateExpressionIdentifier:expression.identifier token:expression.token];
    return YES;
}

- (BOOL)visitImplicitIteratorExpression:(GRMustacheImplicitIteratorExpression *)expression error:(NSError **)error
{
    return YES;
}

- (BOOL)visitScopedExpression:(GRMustacheScopedExpression *)expression error:(NSError **)error
{
    GRMustacheExpression *baseExpression = expression.baseExpression;
    if ([baseExpression isKindOfClass:[GRMustacheImplicitIteratorExpression class]]) {
        [self addWarningWithCode:GRMustacheWarningMustacheExtensionAnchoredExpression token:expression.token];
    }
    [self validateExpressionIdentifier:expression.identifier token:expression.token];
    return YES;
}


#pragma mark - GRMustacheTemplateParserDelegate

- (BOOL)templateParser:(GRMustacheTemplateParser *)parser shouldContinueAfterParsingToken:(GRMustacheToken *)token
{
    if (![_compiler templateParser:parser shouldContinueAfterParsingToken:token]) {
        return NO;
    }
    
    switch (token.type) {
        case GRMustacheTokenTypeText:
        case GRMustacheTokenTypeEscapedVariable:
        case GRMustacheTokenTypeComment:
        case GRMustacheTokenTypeUnescapedVariable:
        case GRMustacheTokenTypeSetDelimiter:
            break;
            
        case GRMustacheTokenTypeSectionOpening:
        case GRMustacheTokenTypeInvertedSectionOpening:
            // TODO: GRMustacheWarningMustacheExtensionImplicitClosingTag
            break;
            
        case GRMustacheTokenTypeClosing: {
            GRMustacheExpressionParser *expressionParser = [[[GRMustacheExpressionParser alloc] init] autorelease];
            BOOL empty;
            NSError *error;
            GRMustacheExpression *expression = [expressionParser parseExpression:token.tagInnerContent empty:&empty error:&error];
            if (!expression) {
                if (empty) {
                    [self addWarningWithCode:GRMustacheWarningMustacheExtensionEmptyClosingTag token:token];
                } else {
                    [_errors addObject:error];
                }
            }
        } break;
            
        case GRMustacheTokenTypePartial: {
            NSError *error;
            NSString *partialName = [parser parseTemplateName:token.tagInnerContent empty:NULL error:&error];
            if (!partialName) {
                [_errors addObject:error];
            } else if ([partialName characterAtIndex:0] == '/') {
                [self addWarningWithCode:GRMustacheWarningMustacheExtensionAbsolutePartialPath token:token];
            }
        } break;
            
        case GRMustacheTokenTypePragma: {
            [self addWarningWithCode:GRMustacheWarningMustacheExtensionPragma token:token];
            
            NSString *pragma = [parser parsePragma:token.tagInnerContent];
            if (![pragma isEqualToString:GRMustacheCompilerPragmaContentTypeHTML] &&
                ![pragma isEqualToString:GRMustacheCompilerPragmaContentTypeText])
            {
                [self addWarningWithCode:GRMustacheWarningGRMustacheUnsupportedPragma token:token];
            }
        } break;
            
        case GRMustacheTokenTypeInheritablePartial:
        case GRMustacheTokenTypeInheritableSectionOpening:
            [self addWarningWithCode:GRMustacheWarningMustacheExtensionTemplateInheritance token:token];
            break;
    }
    
    return YES;
}

- (void)templateParser:(GRMustacheTemplateParser *)parser didFailWithError:(NSError *)error
{
    [_compiler templateParser:parser didFailWithError:error];
}



#pragma mark - Private

- (void)validateExpression:(GRMustacheExpression *)expression
{
    NSString *expressionString = [_expressionGenerator stringWithExpression:expression];
    
    if ([expressionString isEqualToString:@"capitalized"]) {
        [self addWarningWithCode:GRMustacheWarningMustacheExtensionStandardLibrary token:expression.token];
    }
    
    if ([expressionString isEqualToString:@"lowercase"]) {
        [self addWarningWithCode:GRMustacheWarningMustacheExtensionStandardLibrary token:expression.token];
    }
    
    if ([expressionString isEqualToString:@"uppercase"]) {
        [self addWarningWithCode:GRMustacheWarningMustacheExtensionStandardLibrary token:expression.token];
    }
    
    if ([expressionString isEqualToString:@"isBlank"]) {
        [self addWarningWithCode:GRMustacheWarningMustacheExtensionStandardLibrary token:expression.token];
    }
    
    if ([expressionString isEqualToString:@"isEmpty"]) {
        [self addWarningWithCode:GRMustacheWarningMustacheExtensionStandardLibrary token:expression.token];
    }
    
    if ([expressionString isEqualToString:@"localize"]) {
        [self addWarningWithCode:GRMustacheWarningMustacheExtensionStandardLibrary token:expression.token];
    }
    
    if ([expressionString isEqualToString:@"each"]) {
        [self addWarningWithCode:GRMustacheWarningMustacheExtensionStandardLibrary token:expression.token];
    }
    
    if ([expressionString isEqualToString:@"HTML.escape"]) {
        [self addWarningWithCode:GRMustacheWarningMustacheExtensionStandardLibrary token:expression.token];
    }
    
    if ([expressionString isEqualToString:@"javascript.escape"]) {
        [self addWarningWithCode:GRMustacheWarningMustacheExtensionStandardLibrary token:expression.token];
    }
    
    if ([expressionString isEqualToString:@"URL.escape"]) {
        [self addWarningWithCode:GRMustacheWarningMustacheExtensionStandardLibrary token:expression.token];
    }
}

- (void)validateExpressionIdentifier:(NSString *)identifier token:(GRMustacheToken *)token
{
    if ([identifier rangeOfString:@"/"].location != NSNotFound) {
        [self addWarningWithCode:GRMustacheWarningGRMustacheDeprecationSlashInIdentifier token:token];
    }
}

- (void)addWarningWithCode:(GRMustacheWarning)warning token:(GRMustacheToken *)token
{
    NSString *warningText = nil;
    switch (warning) {
        case GRMustacheWarningGRMustacheDeprecationSlashInIdentifier:
            warningText = @"Slash in identifier is deprecated in GRMustache";
            break;
        case GRMustacheWarningGRMustacheUnsupportedPragma:
            warningText = @"Pragma tag that is unsupported by GRMustache";
            break;
        case GRMustacheWarningMustacheExtensionPragma:
            warningText = @"Extension: pragma tag";
            break;
        case GRMustacheWarningMustacheExtensionFilter:
            warningText = @"Extension: filter expression";
            break;
        case GRMustacheWarningMustacheExtensionEmptyClosingTag:
            warningText = @"Extension: empty closing tag";
            break;
        case GRMustacheWarningMustacheExtensionImplicitClosingTag:
            warningText = @"Extension: implicit closing tag";
            break;
        case GRMustacheWarningMustacheExtensionAnchoredExpression:
            warningText = @"Extension: dot-prefixed expression";
            break;
        case GRMustacheWarningMustacheExtensionAbsolutePartialPath:
            warningText = @"Extension: absolute path to partial";
            break;
        case GRMustacheWarningMustacheExtensionTemplateInheritance:
            warningText = @"Extension: template inheritance";
            break;
        case GRMustacheWarningMustacheExtensionStandardLibrary:
            warningText = @"Extension: GRMustache standard library";
            break;
            break;
    }
    
    NSString *description = [NSString stringWithFormat:@"%@: %@ at line %lu", warningText, token.templateSubstring, (unsigned long)token.line];
    NSError *error = [NSError errorWithDomain:GRMustacheWarningDomain
                                         code:warning
                                     userInfo:@{ NSLocalizedDescriptionKey: description}];
    [_errors addObject:error];
}

@end
