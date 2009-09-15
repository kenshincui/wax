//
//  ObjLua.m
//  Lua
//
//  Created by ProbablyInteractive on 5/27/09.
//  Copyright 2009 Probably Interactive. All rights reserved.
//

#import "oink.h"
#import "oink_class.h"
#import "oink_instance.h"
#import "oink_struct.h"
#import "oink_helpers.h"

#import "lauxlib.h"
#import "lobject.h"
#import "lualib.h"

lua_State *oink_currentLuaState() {
    static lua_State *L;    
    if (!L) L = lua_open();  
    
    return L;
}

void uncaughtExceptionHandler(NSException *e) {
    NSLog(@"OINK! Uncaught exception %@", e);
}

void oink_startWithExtensions(lua_CFunction func, ...) {   
    char *mainFile;    
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager changeCurrentDirectoryPath:OINK_DATA_PATH];
    
    lua_State *L = oink_currentLuaState();    
    
    NSArray *args = [[NSProcessInfo processInfo] arguments];    
    if ([args containsObject:@"test"]) {
        mainFile = "scripts/tests/init.lua";
    }
    else {
        mainFile = "scripts/init.lua"; // Use this for compiled lua files        
        if (![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithUTF8String:mainFile]]) {
          mainFile = "scripts/init.dat";        
        }
    }            
    
    luaL_openlibs(L); 
    luaopen_oink(L);
    
    if (func) { // Load extentions
        func(L);

        va_list ap;
        va_start(ap, func);
        while(func = va_arg(ap, lua_CFunction)) func(L);
            
        va_end(ap);
    }
    
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
    
    addGlobals(L);
    if (luaL_dofile(L, mainFile) != 0) fprintf(stderr,"Fatal Error: %s\n", lua_tostring(L,-1));    
}

void oink_start() {
    oink_startWithExtensions(nil);
}

void oink_end() {
    lua_close(oink_currentLuaState());
}

void luaopen_oink(lua_State *L) {
    luaopen_oink_class(L);
    luaopen_oink_instance(L);
    luaopen_oink_struct(L);
}

static void addGlobals(lua_State *L) {
    // Functions
    lua_pushcfunction(L, tolua);
    lua_setglobal(L, "tolua");
    
    lua_pushcfunction(L, toobjc);
    lua_setglobal(L, "toobjc");
    
    lua_pushcfunction(L, exitApp);
    lua_setglobal(L, "exitApp");
    
    lua_pushcclosure(L, objcDebug, 0);
    lua_setglobal(L, "objcDebug");
    
    // Variables
    lua_pushstring(L, [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] UTF8String]);
    lua_setglobal(L, "NSDocumentDirectory");
    
    lua_pushstring(L, [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] UTF8String]);
    lua_setglobal(L, "NSLibraryDirectory");
}

static int tolua(lua_State *L) {
    if (lua_isuserdata(L, 1)) { // If it's not userdata... it's already lua!
        oink_instance_userdata *instanceUserdata = (oink_instance_userdata *)luaL_checkudata(L, 1, OINK_INSTANCE_METATABLE_NAME);
        oink_fromInstance(L, instanceUserdata->instance);
    }
    
    return 1;
}

static int toobjc(lua_State *L) {
    id *instancePointer = oink_copyToObjc(L, "@", 1, nil);
    id instance = *(id *)instancePointer;
    
    oink_instance_create(L, instance, NO);
    
    free(instancePointer);
    
    return 1;
}

static int exitApp(lua_State *L) {
    exit(0);
    return 0;
}

static int objcDebug(lua_State *L) {
    //Debugger();
    NSLog(@"I don't know how this will work yet. For now just set a breakpoint in the method.");
    return 0;
}