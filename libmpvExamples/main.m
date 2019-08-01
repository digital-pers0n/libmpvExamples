//
//  main.m
//  libmpvExamples
//
//  Created by Terminator on 2019/08/01.
//  Copyright © 2019年 home. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <dlfcn.h>

int main(int argc, const char * argv[]) {
    
    void *g_opengl_framework_handle;
    g_opengl_framework_handle = dlopen("/System/Library/Frameworks/OpenGL.framework/OpenGL",
                                       RTLD_LAZY | RTLD_LOCAL);
    if (!g_opengl_framework_handle) {
        fprintf(stderr, "Cannot load OpenGL.framework\n");
        return EXIT_FAILURE;
    }
    
    return NSApplicationMain(argc, argv);
}
