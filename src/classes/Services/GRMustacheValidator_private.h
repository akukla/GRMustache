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

#import <Foundation/Foundation.h>
#import "GRMustacheAvailabilityMacros_private.h"

@class GRMustacheTemplateRepository;
@class GRMustacheTag;
@class GRMustacheExpressionGenerator;
@class GRMustacheCompiler;

typedef NS_OPTIONS(NSUInteger, GRMustacheWarning) {
    GRMustacheWarningGRMustacheDeprecationSlashInIdentifier  = 1 << 0,     // {{a/b}}
    GRMustacheWarningGRMustacheUnsupportedPragma             = 1 << 1,     // {{% ... }} unknown to GRMustache
    GRMustacheWarningMustacheExtensionPragma                 = 1 << 2,     // {{% ... }}
    GRMustacheWarningMustacheExtensionFilter                 = 1 << 3,     // {{f(x)}}
    GRMustacheWarningMustacheExtensionEmptyClosingTag        = 1 << 4,     // {{#a}}...{{/}}
    GRMustacheWarningMustacheExtensionImplicitClosingTag     = 1 << 5,     // {{#a}}...{{^a}}...{{/a}}
    GRMustacheWarningMustacheExtensionAnchoredExpression     = 1 << 6,     // {{.a}}
    GRMustacheWarningMustacheExtensionAbsolutePartialPath    = 1 << 7,     // {{>/a}}
    GRMustacheWarningMustacheExtensionTemplateInheritance    = 1 << 8,     // {{<layout}}...{{/layout}} {{$overridable}}...{{/overridable}}
    GRMustacheWarningMustacheExtensionStandardLibrary        = 1 << 9,     // localize, each, isBlank, ...
};

typedef NSUInteger GRMustacheWarnings;
extern GRMustacheWarnings const GRMustacheWarningAll;

extern NSString * const GRMustacheWarningDomain;

@interface GRMustacheValidator : NSObject {
@private
    NSMutableArray *_errors;
    GRMustacheTag *_tag;
    GRMustacheExpressionGenerator *_expressionGenerator;
    GRMustacheCompiler *_compiler;
}

- (NSArray *)errorsAndWarningsForTemplateID:(id)templateID templateRepository:(GRMustacheTemplateRepository *)templateRepository GRMUSTACHE_API_PUBLIC;

@end
