-- Example showing how to use torch inside ATS Lua script. Depends on torch

-- Setup instructions
-- 1) Install torch following instructions here - http://torch.ch/docs/getting-started.html
-- (in the example below, I installed torch under /home/root/)
-- 2) Install nn - sudo luarocks install nn

ts.add_package_path('/home/root/.luarocks/share/lua/5.1/?.lua;/home/root/.luarocks/share/lua/5.1/?/init.lua;/home/root/torch/install/share/lua/5.1/?.lua;/home/root/torch/install/share/lua/5.1/?/init.lua;./?.lua;/home/root/torch/install/share/luajit-2.1.0-beta1/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua')
ts.add_package_cpath('/home/root/.luarocks/lib/lua/5.1/?.so;/home/root/torch/install/lib/lua/5.1/?.so;./?.so;/usr/local/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so')

require 'nn'
-- set up a model mentioned in http://mdtux89.github.io/2015/12/11/torch-tutorial.html
mlp = nn.Sequential()

inputSize = 10
hiddenLayer1Size = opt.units
hiddenLayer2Size = opt.units

mlp:add(nn.Linear(inputSize, hiddenLayer1Size))
mlp:add(nn.Tanh())
mlp:add(nn.Linear(hiddenLayer1Size, hiddenLayer2Size))
mlp:add(nn.Tanh())

nclasses = 2

mlp:add(nn.Linear(hiddenLayer2Size, nclasses))
mlp:add(nn.LogSoftMax())

function do_global_read_request()
    -- use the model
    out = mlp:forward(torch.randn(1,10))
    ts.debug(out[1][1])
end
