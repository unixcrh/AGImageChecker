//
//  UIImageView+AGImageChecker.m
//
//  Created by Angel on 9/4/12.
//  Copyright (c) 2012 angelolloqui.com. All rights reserved.
//

#import "UIImageView+AGImageChecker.h"
#import "UIImage+AGImageChecker.h"
#import <objc/runtime.h>

#define CGSizeIsBiggerThan(size1, size2) ((size1.width > size2.width) || (size1.height > size2.height))
#define CGSizeIsStrictlyBiggerThan(size1, size2) ((size1.width > size2.width) && (size1.height > size2.height))
#define CGSizeIsProportionalTo(size1, size2) ((size1.width / size2.width) == (size1.height / size2.height))
#define floatIsDecimal(num) (num - ((int) num) != 0.0f)

@implementation UIImageView (AGImageChecker)

@dynamic issues;

#pragma mark Public API

static BOOL methodsAlreadySwizzled = NO;
+ (void)startCheckingImages {
    if (!methodsAlreadySwizzled) {
        methodsAlreadySwizzled = YES;
        [self swizzle];
    }
}

+ (void)stopCheckingImages {
    if (methodsAlreadySwizzled) {
        methodsAlreadySwizzled = NO;
        [self swizzle];
    }
}

static AGImageIssuesHandler sIssuesHandler = nil;
+ (void)setImageIssuesHandler:(AGImageIssuesHandler)handler {
    sIssuesHandler = [handler copy];
}

#pragma mark Swizzling methods

+ (void)swizzle {
#ifdef DEBUG
    //Swizzle the original setImage method to add our own calls
    Method setImageOriginal = class_getInstanceMethod(self, @selector(setImage:));
    Method setImageCustom = class_getInstanceMethod(self, @selector(setImageCustom:));
    method_exchangeImplementations(setImageOriginal, setImageCustom);    
    
    //Swizzle the original setFrame method to add our own calls
    Method setFrameOriginal = class_getInstanceMethod(self, @selector(setFrame:));
    Method setFrameCustom = class_getInstanceMethod(self, @selector(setFrameCustom:));
    method_exchangeImplementations(setFrameOriginal, setFrameCustom);    
    
    //Swizzle the original setContentMode method to add our own calls
    Method setContentModeOriginal = class_getInstanceMethod(self, @selector(setContentMode:));
    Method setContentModeCustom = class_getInstanceMethod(self, @selector(setContentModeCustom:));
    method_exchangeImplementations(setContentModeOriginal, setContentModeCustom);    
    
    //Swizzle the original initWithCoder method to add our own calls
    Method initWithCoderOriginal = class_getInstanceMethod(self, @selector(initWithCoder:));
    Method initWithCoderCustom = class_getInstanceMethod(self, @selector(initWithCoderCustom:));
    method_exchangeImplementations(initWithCoderOriginal, initWithCoderCustom);    
    
    //Swizzle the original layoutSubviews method to add our own calls
    Method setLayoutSubviewsOriginal = class_getInstanceMethod(self, @selector(layoutSubviews));
    Method setLayoutSubviewsCustom = class_getInstanceMethod(self, @selector(layoutSubviewsCustom));
    method_exchangeImplementations(setLayoutSubviewsOriginal, setLayoutSubviewsCustom);    
#endif
}

- (void)setImageCustom:(UIImage *)image {
    if ([self isKindOfClass:[UIImageView class]]) {
        UIImage *oldImage = self.image;
        //Call the original method (was swizzled)
        [self setImageCustom:image];    
        if (image != oldImage) {
            [self checkImage];
            if ([self.accessibilityLabel length] <= 0) {
                self.accessibilityLabel = image.name;
            }
        }
    }
}

- (void)setFrameCustom:(CGRect)frame {
    if ([self isKindOfClass:[UIImageView class]]) {
        CGRect oldFrame = self.frame;
        //Call the original method (was swizzled)
        [self setFrameCustom:frame];    
        if (!CGRectEqualToRect(frame, oldFrame)) {
            [self checkImage];
        }
    }
}

- (void)setContentModeCustom:(UIViewContentMode)mode {
    if ([self isKindOfClass:[UIImageView class]]) {
        UIViewContentMode oldMode = self.contentMode;
        //Call the original method (was swizzled)
        [self setContentModeCustom:mode];    
        if (mode != oldMode) {
            [self checkImage];    
        }
    }
}

- (id)initWithCoderCustom:(NSCoder *)aDecoder {
    if ([self isKindOfClass:[UIImageView class]]) {
        //Call the original method (was swizzled)
        self = [self initWithCoderCustom:aDecoder];    
        [self checkImage];
    }
    return self;
}

- (void)layoutSubviewsCustom {
    if ([self isKindOfClass:[UIImageView class]]) {
        //Call the original method (was swizzled)
        [self layoutSubviewsCustom];
        [self checkImage];
    }
}

#pragma mark Checking issues

- (void)checkImage {
    
    //Check Missing images
    AGImageCheckerIssue issues = AGImageCheckerIssueNone;
    if (self.image == nil || [self.image isEmptyImage]) {
        issues = AGImageCheckerIssueMissing;
    }
    //If image not missing, check if it is stretchable
    else if (UIEdgeInsetsEqualToEdgeInsets(self.image.capInsets, UIEdgeInsetsZero)) {       
        CGSize imgSize = self.image.size;
        CGSize viewSize = self.bounds.size;
        
        //Retina image and view resizing
        CGFloat imgScale = self.image.scale;
        imgSize = CGSizeMake(imgSize.width * imgScale, imgSize.height * imgScale);        
        CGFloat viewScale = [UIScreen mainScreen].scale;
        viewSize = CGSizeMake(viewSize.width * viewScale, viewSize.height * viewScale);

        if (self.contentMode == UIViewContentModeScaleAspectFill) {        
            if ((imgSize.width != viewSize.width) || (imgSize.height != viewSize.height)) {
                issues |= AGImageCheckerIssueResized;
            }
            if (CGSizeIsBiggerThan(viewSize, imgSize)) {
                issues |= AGImageCheckerIssueBlurry;
            }        
            if (!CGSizeIsProportionalTo(viewSize, imgSize)){
                issues |= AGImageCheckerIssuePartiallyHidden;
            }
        }
        else if (self.contentMode == UIViewContentModeScaleAspectFit) {
            if (CGSizeIsStrictlyBiggerThan(viewSize, imgSize)) {
                issues |= AGImageCheckerIssueResized;
                issues |= AGImageCheckerIssueBlurry;
            }        
            else if (CGSizeIsStrictlyBiggerThan(imgSize, viewSize)) {
                issues |= AGImageCheckerIssueResized;
            }        
        }
        else if (self.contentMode == UIViewContentModeScaleToFill) {
            if (CGSizeIsBiggerThan(viewSize, imgSize)) {
                issues |= AGImageCheckerIssueResized;
                issues |= AGImageCheckerIssueBlurry;
            }        
            else if (CGSizeIsBiggerThan(imgSize, viewSize)) {
                issues |= AGImageCheckerIssueResized;
            }
            if (!CGSizeIsProportionalTo(viewSize, imgSize)){
                issues |= AGImageCheckerIssueStretched;
            }
        }
        else {
            if (CGSizeIsBiggerThan(imgSize, viewSize)) {
                issues |= AGImageCheckerIssuePartiallyHidden;
            }        
            
            //When setting to center the image can be aligned to 0.5. Check it returns blurry
            if (self.contentMode == UIViewContentModeCenter) {
                CGFloat deltaX = (imgSize.width - viewSize.width) / 2.0;
                CGFloat deltaY = (imgSize.height - viewSize.height) / 2.0;
                if ((floatIsDecimal(deltaX)) || (floatIsDecimal(deltaY))) {
                    issues |= AGImageCheckerIssueBlurry;
                    issues |= AGImageCheckerIssueMissaligned;
                }
            }
        }
    }
    
    
    //If the image seems not to be missaligned, check the parents agains their own parents.
    //Note: we can not check the image against the window because it may be in a scrollview, animating, with a float contentOffset, but that is correct if the image is correctly aligned within the scroll
    if (!(issues & AGImageCheckerIssueMissaligned)) {
        UIView *view = self;        
        while (view) {
            //Check if the view is correctly aligned
            CGPoint viewPosition = view.frame.origin;
            if ((floatIsDecimal(viewPosition.x)) || (floatIsDecimal(viewPosition.y))) {
                issues |= AGImageCheckerIssueBlurry;
                issues |= AGImageCheckerIssueMissaligned;
                break;
            }
            view = view.superview;
        }        
    }
    
    self.issues = issues;
}

#pragma mark Properties

static void * const kMyAssociatedIssuesKey = (void*)&kMyAssociatedIssuesKey; 
- (AGImageCheckerIssue)issues {
    return (AGImageCheckerIssue)[(NSNumber *)objc_getAssociatedObject(self, kMyAssociatedIssuesKey) intValue];
}

- (void)setIssues:(AGImageCheckerIssue)issues {
    objc_setAssociatedObject(self, kMyAssociatedIssuesKey, [NSNumber numberWithInt:issues], OBJC_ASSOCIATION_RETAIN);
    if (sIssuesHandler) {
        sIssuesHandler(self, issues);
    }
}

@end
