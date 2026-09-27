function love.conf(t)
	t.author = "Maurice"
	t.identity = "mari0"
	t.console = false
	t.modules.physics = false
	t.version = "11.4"
	-- Load before main.lua so the touch callbacks and draw wrapper are installed.
	pcall(require, "mobilecontrols")
end
