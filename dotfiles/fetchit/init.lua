column_padding = 2

art = {
    source = "./logos/logo.txt"
}

function fetch()
    return {
        columns = {
            art.out,
            {
                color.white(user.name .. "@" .. host.name),
                color.red("os:      ") .. "rddbg os | 'fedora linux 44'",
                color.yellow("kernel:  ") .. "fedora " .. kernel.release,
                color.green("cpu:     ") .. string.lower(cpu.name),
                color.blue("gpu:     ") .. "nvidia geforce rtx 5070",
                color.magenta("ram:     ") .. string.format("%.1fGB/%.1fGB (%.1f%%)", memory.used_gb, memory.total_gb, memory.percent),
                color.cyan("uptime:  ") .. uptime.pretty,
            }
        }
    }
end
