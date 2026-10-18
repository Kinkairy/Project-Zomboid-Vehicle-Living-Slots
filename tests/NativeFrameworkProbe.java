import java.lang.reflect.*;
import java.nio.file.*;
import java.util.*;

// Bounded probe: actual game Lua VM and argument collector, without a world.
public class NativeFrameworkProbe {
    static Class<?> cls(String name) throws Exception { return Class.forName(name); }
    public static void main(String[] args) throws Exception {
        Class<?> table = cls("se.krka.kahlua.vm.KahluaTable");
        Class<?> platform = cls("se.krka.kahlua.vm.Platform");
        Object p = cls("se.krka.kahlua.j2se.J2SEPlatform").getMethod("getInstance").invoke(null);
        Object env = p.getClass().getMethod("newEnvironment").invoke(p);
        Class<?> manager = cls("se.krka.kahlua.converter.KahluaConverterManager");
        Class<?> exposerClass = cls("zombie.Lua.LuaManager$Exposer");
        Object exposer = exposerClass.getConstructor(manager, platform, table)
            .newInstance(manager.getConstructor().newInstance(), p, env);
        Class<?> globals = cls("zombie.Lua.LuaManager$GlobalObject");
        Method convert = globals.getMethod("convertToPZNetTable", table);
        exposerClass.getMethod("exposeGlobalClassFunction", table, Class.class, Method.class, String.class)
            .invoke(exposer, env, globals, convert, "convertToPZNetTable");
        Object thread = cls("se.krka.kahlua.vm.KahluaThread").getConstructor(platform, table).newInstance(p, env);
        thread.getClass().getField("debugOwnerThread").set(thread, Thread.currentThread());
        cls("zombie.Lua.LuaManager").getField("thread").set(null, thread);
        cls("zombie.Lua.LuaManager").getField("env").set(null, env);
        Object fn = cls("se.krka.kahlua.luaj.compiler.LuaCompiler")
            .getMethod("loadstring", String.class, String.class, table)
            .invoke(null, Files.readString(Path.of(args[0])), "native-framework-contract", env);
        if (args.length > 1 && args[1].equals("compile-only")) {
            System.out.println("PASS actual Kahlua compile " + Path.of(args[0]).getFileName());
            return;
        }
        Object[] result = (Object[])thread.getClass().getMethod("pcall", Object.class, Object[].class)
            .invoke(thread, fn, new Object[0]);
        if (!Boolean.TRUE.equals(result[0])) throw new AssertionError(Arrays.toString(result));
        if (args.length > 1 && args[1].equals("lua-only")) {
            Object reached = table.getMethod("rawget", Object.class).invoke(env, "suitePassed");
            if (!Boolean.TRUE.equals(reached)) throw new AssertionError("suite completion marker missing");
            Object transcript = table.getMethod("rawget", Object.class).invoke(env, "fixtureTranscript");
            if (transcript instanceof String) System.out.println(transcript);
            System.out.println("PASS actual Kahlua fixture " + Path.of(args[0]).getFileName());
            return;
        }
        Method get = table.getMethod("rawget", Object.class);
        for (String which : new String[]{"ordinaryAction", "nativeCabinetAction"}) {
            Object action = get.invoke(env, which);
            Object net = cls("zombie.core.NetTimedAction").getConstructor().newInstance();
            try {
                net.getClass().getMethod("set", cls("zombie.characters.IsoPlayer"), table).invoke(net, null, action);
            } catch (InvocationTargetException ex) {
                Throwable cause = ex.getCause();
                if (!(cause instanceof NullPointerException) || Arrays.stream(cause.getStackTrace())
                    .noneMatch(x -> x.getClassName().equals("zombie.core.Action") && x.getMethodName().equals("set"))) throw ex;
            }
            Field field = net.getClass().getDeclaredField("actionArgs");
            field.setAccessible(true);
            Object actual = field.get(net);
            List<String> keys = new ArrayList<>(List.of("character", "craftRecipe", "containers", "isoObject", "craftBench",
                "manualInputs", "items", "recipeItem", "variableInputRatio", "eatPercentage"));
            if (which.equals("nativeCabinetAction")) keys.addAll(List.of("vehicleId", "partId", "installedItemId", "installationEpoch"));
            for (String key : keys) {
                Object expected = get.invoke(action, key), value = get.invoke(actual, key);
                if (expected == null) {
                    if (value == null || !value.getClass().getName().equals("zombie.network.PZNetKahluaNull"))
                        throw new AssertionError(which + " lost null placeholder " + key);
                } else if (!expected.equals(value)) throw new AssertionError(which + " lost " + key);
            }
            int size = ((Number)actual.getClass().getMethod("size").invoke(actual)).intValue();
            if (size != keys.size()) throw new AssertionError(which + " unexpected argument count " + size);
            System.out.println("PASS actual NetTimedAction.set " + which + " " + size + " named arguments");
        }
    }
}
