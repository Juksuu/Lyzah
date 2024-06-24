local dap = require("dap")

dap.adapters.lldb = {
	type = "executable",
	command = "lldb-vscode",
	name = "lldb",
}

dap.configurations.zig = {
	{
		name = "Sandbox",
		type = "lldb",
		request = "launch",
		program = function()
			return vim.fn.getcwd() .. "/Sandbox/zig-out/bin/Sandbox"
		end,
		cwd = "${workspaceFolder}/Sandbox/",
		stopOnEntry = false,
	},
}
