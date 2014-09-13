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
#import "GRMustacheTemplateGenerator_private.h"
#import "GRMustacheExpressionParser_private.h"


NSString * const GRMustacheWarningDomain = @"GRMustacheWarningDomain";

@interface GRMustacheValidator()<GRMustacheTemplateASTVisitor, GRMustacheExpressionVisitor, GRMustacheTemplateParserDelegate>
@end

@implementation GRMustacheValidator

- (NSArray *)errorsForTemplateID:(id)templateID templateRepository:(GRMustacheTemplateRepository *)templateRepository
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
    
    _templateGenerator = [GRMustacheTemplateGenerator templateGeneratorWithTemplateRepository:templateRepository];
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
    [self addWarningWithCode:GRMustacheWarningExtensionFilter
                 description:[NSString stringWithFormat:@"Filter expression at line %lu", (unsigned long)expression.token.line]];
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
        [self addWarningWithCode:GRMustacheWarningExtensionAnchoredExpression
                     description:[NSString stringWithFormat:@"Anchored expression at line %lu", (unsigned long)expression.token.line]];
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
            // TODO: GRMustacheWarningExtensionImplicitClosingTag
            break;
            
        case GRMustacheTokenTypeClosing: {
            GRMustacheExpressionParser *expressionParser = [[[GRMustacheExpressionParser alloc] init] autorelease];
            BOOL empty;
            NSError *error;
            GRMustacheExpression *expression = [expressionParser parseExpression:token.tagInnerContent empty:&empty error:&error];
            if (!expression) {
                if (empty) {
                    [self addWarningWithCode:GRMustacheWarningExtensionEmptyClosingTag
                                 description:[NSString stringWithFormat:@"Empty closing tag at line %lu", (unsigned long)token.line]];
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
                [self addWarningWithCode:GRMustacheWarningExtensionAbsolutePartialPath
                             description:[NSString stringWithFormat:@"Absolute path to partial at line %lu", (unsigned long)token.line]];
            }
        } break;
            
        case GRMustacheTokenTypePragma:
            [self addWarningWithCode:GRMustacheWarningExtensionPragma
                         description:[NSString stringWithFormat:@"Pragma tag at line %lu", (unsigned long)token.line]];
            // TODO: GRMustacheWarningUnsupportedPragma
            break;
            
        case GRMustacheTokenTypeInheritablePartial:
        case GRMustacheTokenTypeInheritableSectionOpening:
            // TODO: GRMustacheWarningExtensionTemplateInheritance
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
    NSString *expressionString = [_templateGenerator stringWithExpression:expression];
    if ([expressionString isEqualToString:@"localize"]) {
        [self addWarningWithCode:GRMustacheWarningExtensionStandardLibrary
                     description:[NSString stringWithFormat:@"`localize` at line %lu", (unsigned long)expression.token.line]];
    }
    if ([expressionString isEqualToString:@"URL.escape"]) {
        [self addWarningWithCode:GRMustacheWarningExtensionStandardLibrary
                     description:[NSString stringWithFormat:@"`URL.escape` at line %lu", (unsigned long)expression.token.line]];
    }
}

- (void)validateExpressionIdentifier:(NSString *)identifier token:(GRMustacheToken *)token
{
    if ([identifier rangeOfString:@"/"].location != NSNotFound) {
        [self addWarningWithCode:GRMustacheWarningDeprecatedSlashInIdentifier
                     description:[NSString stringWithFormat:@"Slash in identifier at line %lu", (unsigned long)token.line]];
    }
}

- (void)addWarningWithCode:(GRMustacheWarning)warning description:(NSString *)description
{
    NSError *error = [NSError errorWithDomain:GRMustacheWarningDomain
                                         code:warning
                                     userInfo:@{ NSLocalizedDescriptionKey: description}];
    [_errors addObject:error];
}

@end
