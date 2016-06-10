/* compile by running "gcc -Wall -shared -fPIC -o power.so -I/usr/local/include/ -llua power.c" */

#include <lua.h>                               /* Always include this */
#include <lauxlib.h>                           /* Always include this */
#include <lualib.h>                            /* Always include this */

static int isquare(lua_State *L){              /* Internal name of func */
  float rtrn = lua_tonumber(L, -1);      /* Get the single number arg */
  lua_pushnumber(L,rtrn*rtrn);           /* Push the return */
  return 1;                              /* One return value */
}
static int icube(lua_State *L){                /* Internal name of func */
  float rtrn = lua_tonumber(L, -1);      /* Get the single number arg */
  lua_pushnumber(L,rtrn*rtrn*rtrn);      /* Push the return */
  return 1;                              /* One return value */
}

int luaopen_power(lua_State *L){
  lua_register(
      L,               /* Lua state variable */
      "square",        /* func name as known in Lua */
      isquare          /* func name in this file */
      );  
  lua_register(L,"cube",icube);
  return 0;
}

