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

#define GRMUSTACHE_VERSION_MAX_ALLOWED GRMUSTACHE_VERSION_7_0
#import "GRMustachePublicAPITest.h"

@interface GRMustacheTemplateRepositoryWithBundleTest : GRMustachePublicAPITest
@end

@implementation GRMustacheTemplateRepositoryWithBundleTest

- (void)testTemplateRepositoryWithBundle
{
    NSError *error;
    GRMustacheTemplateRepository *repository = [GRMustacheTemplateRepository templateRepositoryWithBundle:self.testBundle];
    
    {
        GRMustacheTemplate *template = [repository templateNamed:@"notFound" error:&error];
        XCTAssertNil(template, @"");
        XCTAssertNotNil(error, @"");
    }
    {
        GRMustacheTemplate *template = [repository templateNamed:@"GRMustacheTemplateRepositoryWithBundleTest" error:NULL];
        NSString *result = [template renderObject:nil error:NULL];
        XCTAssertEqualObjects(result, @"GRMustacheTemplateRepositoryWithBundleTest.mustache GRMustacheTemplateRepositoryWithBundleTest_partial.mustache", @"");
    }
    {
        GRMustacheTemplate *template = [repository templateFromString:@"{{>GRMustacheTemplateRepositoryWithBundleTest}}" error:NULL];
        NSString *result = [template renderObject:nil error:NULL];
        XCTAssertEqualObjects(result, @"GRMustacheTemplateRepositoryWithBundleTest.mustache GRMustacheTemplateRepositoryWithBundleTest_partial.mustache", @"");
    }
    {
        GRMustacheTemplate *template = [repository templateFromString:@"{{>GRMustacheTemplateRepositoryWithBundleTestResources/partial}}" error:NULL];
        NSString *result = [template renderObject:nil error:NULL];
        XCTAssertEqualObjects(result, @"partial sibling GRMustacheTemplateRepositoryWithBundleTest.mustache GRMustacheTemplateRepositoryWithBundleTest_partial.mustache", @"");
    }
}

- (void)testTemplateRepositoryWithBundle_templateExtension_encoding
{
    NSError *error;
    {
        GRMustacheTemplateRepository *repository = [GRMustacheTemplateRepository templateRepositoryWithBundle:self.testBundle
                                                                                            templateExtension:@"text"
                                                                                                     encoding:NSUTF8StringEncoding];
        {
            GRMustacheTemplate *template = [repository templateNamed:@"notFound" error:&error];
            XCTAssertNil(template, @"");
            XCTAssertNotNil(error, @"");
        }
        {
            GRMustacheTemplate *template = [repository templateNamed:@"GRMustacheTemplateRepositoryWithBundleTest" error:NULL];
            NSString *result = [template renderObject:nil error:NULL];
            XCTAssertEqualObjects(result, @"GRMustacheTemplateRepositoryWithBundleTest.text GRMustacheTemplateRepositoryWithBundleTest_partial.text", @"");
        }
        {
            GRMustacheTemplate *template = [repository templateFromString:@"{{>GRMustacheTemplateRepositoryWithBundleTest}}" error:NULL];
            NSString *result = [template renderObject:nil error:NULL];
            XCTAssertEqualObjects(result, @"GRMustacheTemplateRepositoryWithBundleTest.text GRMustacheTemplateRepositoryWithBundleTest_partial.text", @"");
        }
    }
    {
        GRMustacheTemplateRepository *repository = [GRMustacheTemplateRepository templateRepositoryWithBundle:self.testBundle
                                                                                            templateExtension:@""
                                                                                                     encoding:NSUTF8StringEncoding];
        {
            GRMustacheTemplate *template = [repository templateNamed:@"notFound" error:&error];
            XCTAssertNil(template, @"");
            XCTAssertNotNil(error, @"");
        }
        {
            GRMustacheTemplate *template = [repository templateNamed:@"GRMustacheTemplateRepositoryWithBundleTest" error:NULL];
            NSString *result = [template renderObject:nil error:NULL];
            XCTAssertEqualObjects(result, @"GRMustacheTemplateRepositoryWithBundleTest GRMustacheTemplateRepositoryWithBundleTest_partial", @"");
        }
        {
            GRMustacheTemplate *template = [repository templateFromString:@"{{>GRMustacheTemplateRepositoryWithBundleTest}}" error:NULL];
            NSString *result = [template renderObject:nil error:NULL];
            XCTAssertEqualObjects(result, @"GRMustacheTemplateRepositoryWithBundleTest GRMustacheTemplateRepositoryWithBundleTest_partial", @"");
        }
    }
    {
        GRMustacheTemplateRepository *repository = [GRMustacheTemplateRepository templateRepositoryWithBundle:self.testBundle
                                                                                            templateExtension:nil
                                                                                                     encoding:NSUTF8StringEncoding];
        {
            GRMustacheTemplate *template = [repository templateNamed:@"notFound" error:&error];
            XCTAssertNil(template, @"");
            XCTAssertNotNil(error, @"");
        }
        {
            GRMustacheTemplate *template = [repository templateNamed:@"GRMustacheTemplateRepositoryWithBundleTest" error:NULL];
            NSString *result = [template renderObject:nil error:NULL];
            XCTAssertEqualObjects(result, @"GRMustacheTemplateRepositoryWithBundleTest GRMustacheTemplateRepositoryWithBundleTest_partial", @"");
        }
        {
            GRMustacheTemplate *template = [repository templateFromString:@"{{>GRMustacheTemplateRepositoryWithBundleTest}}" error:NULL];
            NSString *result = [template renderObject:nil error:NULL];
            XCTAssertEqualObjects(result, @"GRMustacheTemplateRepositoryWithBundleTest GRMustacheTemplateRepositoryWithBundleTest_partial", @"");
        }
    }
}

- (void)testTemplateRepositoryWithBundleLocalization
{
    // Check that our custom bundles works as expected:
    // - NSLocalizedString
    // - resources files
    // - localized resource files
    // - resources directories
    // - localized resources directories
    NSDictionary *resources = @{ @"nonLocalized.txt": @"nonLocalized",
                                 @"nonLocalizedResources/a.txt": @"nonLocalized a",
                                 @"en.lproj/localized.txt": @"localized",
                                 @"en.lproj/localizedResources/a.txt": @"localized a",
                                 @"en.lproj/Localizable.strings": @"\"key\"=\"value\";" };
    [self runTestsWithBundleResources:resources usingBlock:^(NSBundle *bundle) {
        NSString *localizedString = [bundle localizedStringForKey:@"key" value:@"" table:nil];
        XCTAssertEqualObjects(localizedString, @"value");
        
        NSString *nonLocalizedResourcePath = [bundle pathForResource:@"nonLocalized" ofType:@"txt"];
        NSString *nonLocalizedResourceContent = [NSString stringWithContentsOfFile:nonLocalizedResourcePath encoding:NSUTF8StringEncoding error:NULL];
        XCTAssertEqualObjects(nonLocalizedResourceContent, @"nonLocalized");
        
        NSURL *nonLocalizedResourceURL = [bundle URLForResource:@"nonLocalized" withExtension:@"txt"];
        nonLocalizedResourceContent = [NSString stringWithContentsOfURL:nonLocalizedResourceURL encoding:NSUTF8StringEncoding error:NULL];
        XCTAssertEqualObjects(nonLocalizedResourceContent, @"nonLocalized");

        nonLocalizedResourceURL = [[bundle URLForResource:@"nonLocalizedResources" withExtension:nil] URLByAppendingPathComponent:@"a.txt"];
        nonLocalizedResourceContent = [NSString stringWithContentsOfURL:nonLocalizedResourceURL encoding:NSUTF8StringEncoding error:NULL];
        XCTAssertEqualObjects(nonLocalizedResourceContent, @"nonLocalized a");

        nonLocalizedResourceURL = [bundle URLForResource:@"a" withExtension:@"txt" subdirectory:@"nonLocalizedResources"];
        nonLocalizedResourceContent = [NSString stringWithContentsOfURL:nonLocalizedResourceURL encoding:NSUTF8StringEncoding error:NULL];
        XCTAssertEqualObjects(nonLocalizedResourceContent, @"nonLocalized a");
        
        NSURL *localizedResourceURL = [bundle URLForResource:@"localized" withExtension:@"txt"];
        NSString *localizedResourceContent = [NSString stringWithContentsOfURL:localizedResourceURL encoding:NSUTF8StringEncoding error:NULL];
        XCTAssertEqualObjects(localizedResourceContent, @"localized");
        
        localizedResourceURL = [[bundle URLForResource:@"localizedResources" withExtension:nil] URLByAppendingPathComponent:@"a.txt"];
        localizedResourceContent = [NSString stringWithContentsOfURL:localizedResourceURL encoding:NSUTF8StringEncoding error:NULL];
        XCTAssertEqualObjects(localizedResourceContent, @"localized a");
        
        localizedResourceURL = [bundle URLForResource:@"a" withExtension:@"txt" subdirectory:@"localizedResources"];
        localizedResourceContent = [NSString stringWithContentsOfURL:localizedResourceURL encoding:NSUTF8StringEncoding error:NULL];
        XCTAssertEqualObjects(localizedResourceContent, @"localized a");
    }];
    
    
    // Regression test for https://github.com/groue/GRMustache/issues/87
    
    resources = @{ @"en.lproj/Main.mustache": @"{{> Footer }}",
                   @"en.lproj/Footer.mustache": @"Footer" };
    [self runTestsWithBundleResources:resources usingBlock:^(NSBundle *bundle) {
        GRMustacheTemplate *template = [GRMustacheTemplate templateFromResource:@"Main" bundle:bundle error:NULL];
        NSString *rendering = [template renderObject:nil error:NULL];
        XCTAssertEqualObjects(rendering, @"Footer");
    }];
    
    
    // Non-localized siblings
    
    resources = @{ @"a.mustache": @"{{>b}}",
                   @"b.mustache": @"b" };
    [self runTestsWithBundleResources:resources usingBlock:^(NSBundle *bundle) {
        GRMustacheTemplate *template = [GRMustacheTemplate templateFromResource:@"a" bundle:bundle error:NULL];
        NSString *rendering = [template renderObject:nil error:NULL];
        XCTAssertEqualObjects(rendering, @"b");
    }];
}

- (void)runTestsWithBundleResources:(NSDictionary *)resources usingBlock:(void(^)(NSBundle *bundle))block
{
    static NSUInteger count = 0;    // counter makes sure we do never generate two bundles at the same path, and suffer from NSBundle cache.
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *bundlePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"GRMustacheTest_%lu", (unsigned long)count++]];
    [fm removeItemAtPath:bundlePath error:nil];
    
    for (NSString *name in resources) {
        NSString *string = [resources objectForKey:name];
        NSString *path = [bundlePath stringByAppendingPathComponent:name];
        [fm createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
        [fm createFileAtPath:path contents:[string dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
    }
    
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    block(bundle);
    
    // clean up
    
    [fm removeItemAtPath:bundlePath error:NULL];
}

@end
