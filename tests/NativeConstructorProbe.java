// Exercise the installed game's real NetTimedAction.set argument collector.
// Host/player startup is intentionally absent; no world or server is modified.
import java.lang.reflect.*;
import java.nio.file.*;
import java.util.*;
public class NativeConstructorProbe {
 static Class<?> c(String s)throws Exception{return Class.forName(s);}
 public static void main(String[] args)throws Exception {
  Class<?> table=c("se.krka.kahlua.vm.KahluaTable"),platform=c("se.krka.kahlua.vm.Platform");
  Object p=c("se.krka.kahlua.j2se.J2SEPlatform").getMethod("getInstance").invoke(null);
  Object env=p.getClass().getMethod("newEnvironment").invoke(p);
  Class<?> cm=c("se.krka.kahlua.converter.KahluaConverterManager");
  Object converter=cm.getConstructor().newInstance();
  Class<?> expose=c("zombie.Lua.LuaManager$Exposer");
  Object exposer=expose.getConstructor(cm,platform,table).newInstance(converter,p,env);
  Class<?> globals=c("zombie.Lua.LuaManager$GlobalObject");
  Method convert=globals.getMethod("convertToPZNetTable",table);
  expose.getMethod("exposeGlobalClassFunction",table,Class.class,Method.class,String.class)
    .invoke(exposer,env,globals,convert,"convertToPZNetTable");
  Object thread=c("se.krka.kahlua.vm.KahluaThread").getConstructor(platform,table).newInstance(p,env);
  thread.getClass().getField("debugOwnerThread").set(thread,Thread.currentThread());
  c("zombie.Lua.LuaManager").getField("thread").set(null,thread);
  c("zombie.Lua.LuaManager").getField("env").set(null,env);
  Object fn=c("se.krka.kahlua.luaj.compiler.LuaCompiler").getMethod("loadstring",String.class,String.class,table).invoke(null,Files.readString(Path.of(args[0])),"constructor-probe",env);
  Object[] result=(Object[])thread.getClass().getMethod("pcall",Object.class,Object[].class).invoke(thread,fn,new Object[0]);
  if(!Boolean.TRUE.equals(result[0]))throw new AssertionError(Arrays.toString(result));
  Method get=table.getMethod("rawget",Object.class);
  for(String which:new String[]{"ordinaryAction","pantryAction"}){
   Object action=get.invoke(env,which),net=c("zombie.core.NetTimedAction").getConstructor().newInstance();
   try{net.getClass().getMethod("set",c("zombie.characters.IsoPlayer"),table).invoke(net,null,action);}
   catch(InvocationTargetException ex){
    // Only the final Action.set(null-player) call may fail after collection.
    Throwable cause=ex.getCause();
    if(!(cause instanceof NullPointerException)||Arrays.stream(cause.getStackTrace()).noneMatch(x->x.getClassName().equals("zombie.core.Action")&&x.getMethodName().equals("set")))throw ex;
   }
   Field field=net.getClass().getDeclaredField("actionArgs");field.setAccessible(true);Object actual=field.get(net);
   String[] keys=which.equals("ordinaryAction")?new String[]{"character","craftRecipe","containers","isoObject","craftBench","manualInputs","items","recipeItem","variableInputRatio","eatPercentage"}:new String[]{"character","vehicleId","partId","applianceId","choice","manualInputs","items","recipeItem"};
   for(String key:keys){Object expected=get.invoke(action,key),value=get.invoke(actual,key);
    if(expected==null){if(value==null||!value.getClass().getName().equals("zombie.network.PZNetKahluaNull"))throw new AssertionError(which+" missing null placeholder "+key);}
    else if(!expected.equals(value))throw new AssertionError(which+" lost "+key);
   }
   int size=((Number)actual.getClass().getMethod("size").invoke(actual)).intValue();if(size!=keys.length)throw new AssertionError(which+" argument count "+size);
   System.out.println("PASS real NetTimedAction.set "+which+" "+size+" named arguments");
  }
 }
}
