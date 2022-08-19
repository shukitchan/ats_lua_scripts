-- Resize image on the fly

-- Prerequisite 1 - make sure you have ImageMagick

-- sudo yum install ImageMagick-devel

-- Prerequisite 2 - Download, Compile and install lua-imagick
-- Assume that luajit library can be found under /usr/lib64, we need to make the imagick.so library to look for it through dynamic link

-- git clone https://github.com/isage/lua-imagick.git
-- cd lua-imagick
-- sed -i "s/target_link_libraries(imagick \${ImageMagick_LIBRARIES})/target_link_libraries(imagick \${ImageMagick_LIBRARIES} -L\/usr\/lib64 -lluajit-5.1)/" CMakeLists.txt
-- mkdir build
-- cd build
-- cmake ..
-- make
-- sudo make install

-- Put this file in /usr/local/var/lua/imagick.lua and use this in a line in remap.config
-- e.g. map https://www.test.com/test.jpg https://origin.test.com/test.jpb @plugin=tslua.so @pparam=/usr/local/var/lua/imagick.lua

ts.add_package_cpath("/usr/lib64/lua/5.1/?.so")
local magick = require "imagick"

function transform(data, eos)
  ts.ctx["image"] = (ts.ctx["image"] or '') .. data
  
  if eos == 1 then
    local img = magick.open_blob(ts.ctx["image"])
    img:thumbnail(15,15)
    local blob, len = img:blob()
    return blob, eos
  end
  
  return '', eos
end

function do_remap()
  ts.hook(TS_LUA_RESPONSE_TRANSFORM, transform)
  ts.ctx["image"] = ""
  return TS_LUA_REMAP_NO_REMAP
end
