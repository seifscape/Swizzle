//
//  TBMethodHook+IMP.m
//  TBTweakViewController
//
//  Created by Tanner on 3/8/17.
//  Copyright © 2017 Tanner Bennett. All rights reserved.
//

#import "TBMethodHook+IMP.h"
#import "TBValueTypes.h"
#import "TBTrampoline.h"
#import "TBTrampolineLanding.h"
#import <sys/mman.h>

typedef uint8_t byte;

#define BlockReturnSelector(sel) ({ \
    id value = self.hookedReturnValue.value; \
    imp_implementationWithBlock(^(id reciever) { \
        return [value sel]; \
    }); \
})

#define BlockReturn(foo) imp_implementationWithBlock(^(id reciever) { \
    return foo; \
})

@implementation TBMethodHook (IMP)

- (IMP)IMPForHookedReturnType {
    switch (self.method.returnType) {
        case MKTypeEncodingUnknown:
        case MKTypeEncodingVoid: {
            @throw NSInternalInconsistencyException;
            break;
        }
        case MKTypeEncodingChar: {
            return BlockReturnSelector(charValue);
            break;
        }
        case MKTypeEncodingInt: {
            return BlockReturnSelector(intValue);
            break;
        }
        case MKTypeEncodingShort: {
            return BlockReturnSelector(shortValue);
            break;
        }
        case MKTypeEncodingLong: {
            return BlockReturnSelector(longValue);
            break;
        }
        case MKTypeEncodingLongLong: {
            return BlockReturnSelector(longLongValue);
            break;
        }
        case MKTypeEncodingUnsignedChar: {
            return BlockReturnSelector(unsignedCharValue);
            break;
        }
        case MKTypeEncodingUnsignedInt: {
            return BlockReturnSelector(unsignedIntValue);
            break;
        }
        case MKTypeEncodingUnsignedShort: {
            return BlockReturnSelector(unsignedShortValue);
            break;
        }
        case MKTypeEncodingUnsignedLong: {
            return BlockReturnSelector(unsignedLongValue);
            break;
        }
        case MKTypeEncodingUnsignedLongLong: {
            return BlockReturnSelector(unsignedLongValue);
            break;
        }
        case MKTypeEncodingFloat: {
            return BlockReturnSelector(floatValue);
            break;
        }
        case MKTypeEncodingDouble: {
            return BlockReturnSelector(doubleValue);
            break;
        }
        case MKTypeEncodingCBool: {
            return BlockReturnSelector(boolValue);
            break;
        }
        case MKTypeEncodingCString:
        case MKTypeEncodingSelector:
        case MKTypeEncodingPointer: {
            return BlockReturnSelector(pointerValue);
            break;
        }
        case MKTypeEncodingStruct:
        case MKTypeEncodingUnion:
        case MKTypeEncodingBitField:
        case MKTypeEncodingArray: {
            const char *returnType = self.method.signature.methodReturnType;
            #define SAME(str, Type) (strcmp(str, @encode(Type)) == 0)

            if (SAME(returnType, NSRange)) {
                return BlockReturnSelector(rangeValue);
            }

            else if (SAME(returnType, CGPoint) ||
                     SAME(returnType, CGVector) ||
                     SAME(returnType, CGSize) ||
                     SAME(returnType, UIOffset) ||
                     SAME(returnType, UIEdgeInsets)) {
                return BlockReturnSelector(CGPointValue);
            }
            else if (SAME(returnType, CGRect)) {
                return BlockReturnSelector(CGRectValue);
            }
            else if (SAME(returnType, CGAffineTransform)) {
                return BlockReturnSelector(CGAffineTransformValue);
            }

            else if (SAME(returnType, CATransform3D)) {
                return BlockReturnSelector(CATransform3DValue);
            }

            else {
                [NSException raise:NSInternalInconsistencyException format:@"Unsupported return type hook"];
                return nil;
            }

            break;
        }
        case MKTypeEncodingObjcObject:
        case MKTypeEncodingObjcClass: {
            return BlockReturn(self.hookedReturnValue.value);
            break;
        }
    }
}

- (IMP)IMPForHookedArguments {
    NSParameterAssert(self.hookedArguments);

    if (!self.hookedArguments.count) {
        return self.originalImplementation;
    }

    for (TBValue *value in self.hookedArguments) {
        if (value.type == TBValueTypeFloat ||
            value.type == TBValueTypeDouble ||
            value.structType & TBStructTypeDualCGFloat ||
            value.structType & TBStructTypeQuadCGFloat) {

            return [self _IMPFromTrampolineAddress:(uintptr_t)TBTrampolineFP];
        }
    }

    return [self _IMPFromTrampolineAddress:(uintptr_t)TBTrampoline];
}

- (IMP)_IMPFromTrampolineAddress:(uintptr_t)functionStart {
    uintptr_t functionEnd   = (uintptr_t)TBTrampolineEnd;
    uintptr_t functionSize  = functionEnd - functionStart;
    uintptr_t originalIMPOffset = (uintptr_t)originalIMP - functionStart;
    uintptr_t landingIMPOffset  = (uintptr_t)landingIMP - functionStart;

    // Allocate memory for function copy
    byte *impl = mmap(NULL, functionSize, PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
    // Copy function to new allocation
    memcpy(impl, (void *)functionStart, functionSize);
    // Write address to original implementation at end of function
    *(IMP *)(impl + originalIMPOffset) = self.originalImplementation;
    *(IMP *)(impl + landingIMPOffset)  = (IMP)TBTrampolineLanding;

    // Change protections: exec for function, read for variable
    [self mprotect:impl length:functionSize options:PROT_READ | PROT_EXEC];
    return (IMP)impl;
}

- (void)mprotect:(void *)addr length:(ssize_t)length options:(int)protections {
    size_t pagesize = sysconf(_SC_PAGESIZE);

    //  Calculate start of page for mprotect.
    void *pagestart = (void*)((uintptr_t)addr & -pagesize);

    if (pagestart != addr) {
        length += (addr - pagestart);
    }

    //  Change memory protection.
    if (mprotect(pagestart, length, protections)) {
        perror("mprotect");
        exit(EXIT_FAILURE);
    }
}

@end
