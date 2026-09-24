// Run in an isolated JVM with the installed game's JAR and stdlib.lua.
// Proves the native cache behavior behind the vehicle-water menu regression.
public class NativeWaterCallbackProbe {
    static Class<?> c(String name) throws Exception { return Class.forName(name); }

    public static void main(String[] args) throws Exception {
        Class<?> platform = c("se.krka.kahlua.vm.Platform");
        Class<?> table = c("se.krka.kahlua.vm.KahluaTable");
        Class<?> factory = c("se.krka.kahlua.j2se.J2SEPlatform");
        Object p = factory.getMethod("getInstance").invoke(null);
        Object env = factory.getMethod("newEnvironment").invoke(p);
        Class<?> threadType = c("se.krka.kahlua.vm.KahluaThread");
        Object thread = threadType.getConstructor(platform, table).newInstance(p, env);
        threadType.getField("debugOwnerThread").set(thread, Thread.currentThread());
        Class<?> manager = c("zombie.Lua.LuaManager");
        manager.getField("env").set(null, env);
        manager.getField("thread").set(null, thread);
        var compile = c("se.krka.kahlua.luaj.compiler.LuaCompiler")
            .getMethod("loadstring", String.class, String.class, table);
        var call = threadType.getMethod("pcall", Object.class, Object[].class);
        var get = manager.getMethod("getFunctionObject", String.class);
        String key = "ISWorldObjectContextMenu.onTakeWater";
        for (int step = 0; step < 3; step++) {
            String code = switch (step) {
                case 0 -> "ISTakeWaterAction={new=function()return 'native' end}; "
                    + "ISWorldObjectContextMenu={onTakeWater=function()return ISTakeWaterAction:new() end}";
                case 1 -> "ISWorldObjectContextMenu.onTakeWater=function()return 'replacement' end";
                default -> "ISTakeWaterAction.new=function()return 'adapted' end";
            };
            Object closure = compile.invoke(null, code, "water-cache-probe", env);
            Object[] result = (Object[]) call.invoke(thread, closure, new Object[0]);
            if (!Boolean.TRUE.equals(result[0])) throw new AssertionError(result[1]);
            Object cached = get.invoke(null, key);
            Object currentTable = table.getMethod("rawget", Object.class)
                .invoke(env, "ISWorldObjectContextMenu");
            Object current = table.getMethod("rawget", Object.class).invoke(currentTable, "onTakeWater");
            if ((cached == current) != (step == 0)) throw new AssertionError("Unexpected cache behavior");
            Object[] value = (Object[]) call.invoke(thread, cached, new Object[0]);
            String expected = step < 2 ? "native" : "adapted";
            if (!Boolean.TRUE.equals(value[0]) || !expected.equals(value[1]))
                throw new AssertionError("Unexpected action construction");
        }
        System.out.println("NATIVE_WATER_CALLBACK_CACHE: late callback replacement bypassed; constructor adapter reached");
    }
}
