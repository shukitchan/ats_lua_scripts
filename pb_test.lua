-- depends on "lua-protobuf"

-- Setup Instructions
-- 1) Download and expand the following - https://github.com/starwing/lua-protobuf/archive/refs/tags/0.4.0.tar.gz 
-- 2) Go into the directory and compile 
-- gcc -shared pb.o -o pb.so -L/usr/lib -lluajit-5.1
-- gcc -I. -I/usr/include/luajit-2.1 -fPIC -c pb.c
-- 3) Copy pb.so to /usr/local/lib/lua/5.1/ and protoc.lua to /usr/local/share/lua/5.1/ eoIP.so 

ts.add_package_path('/usr/local/share/lua/5.1/?.lua')
ts.add_package_cpath('/usr/local/lib/lua/5.1/?.so')

local pb = require "pb"
local protoc = require "protoc"

function do_global_read_request()
  -- load schema from text (just for demo, use protoc.new() in real world)
  assert(protoc:load [[                                    
   message Phone {                                       
      optional string name        = 1;
      optional int64  phonenumber = 2;
   }                               
   message Person {                
      optional string name     = 1;
      optional int32  age      = 2;
      optional string address  = 3;
      repeated Phone  contacts = 4;
   } ]])         
                 
  -- lua table data
  local data = {   
   name = "ilse",                                   
   age  = 18,                                       
   contacts = {                                     
      { name = "alice", phonenumber = 12312341234 },
      { name = "bob",   phonenumber = 45645674567 }
   }                                                                
  }                                                                   
                                                                    
  -- encode lua table data into binary format in lua string and return
  local bytes = assert(pb.encode("Person", data))  
  ts.error(pb.tohex(bytes))                           
                                                 
end
