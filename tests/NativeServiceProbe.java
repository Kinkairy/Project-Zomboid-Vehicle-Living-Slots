// Runs with the installed game JRE/JAR. Isolated Lua environment, real Vector2
// and game Exposer; numeric return conversion installed without booting a server.
import java.lang.reflect.*;
public class NativeServiceProbe {
 static Class<?> c(String name)throws Exception{return Class.forName(name);}
 public static void main(String[] args)throws Exception {
  Class<?> plat=c("se.krka.kahlua.vm.Platform"),table=c("se.krka.kahlua.vm.KahluaTable");
  Class<?> j2=c("se.krka.kahlua.j2se.J2SEPlatform"),cm=c("se.krka.kahlua.converter.KahluaConverterManager");
  Object p=j2.getMethod("getInstance").invoke(null);
  Object env=j2.getMethod("newEnvironment").invoke(p);
  Object converter=cm.getConstructor().newInstance();
  Class<?> javaConverter=c("se.krka.kahlua.converter.JavaToLuaConverter");
  Object numbers=Proxy.newProxyInstance(javaConverter.getClassLoader(),new Class<?>[]{javaConverter},
   (proxy,method,values)->switch(method.getName()){
    case "getJavaType" -> Number.class;
    case "fromJavaToLua" -> ((Number)values[0]).doubleValue();
    default -> null;
   });
  cm.getMethod("addJavaConverter",javaConverter).invoke(converter,numbers);
  Class<?> expose=c("zombie.Lua.LuaManager$Exposer");
  Object exposer=expose.getConstructor(cm,plat,table).newInstance(converter,p,env);
  Class<?> lc=c("se.krka.kahlua.converter.LuaToJavaConverter");
  for(Class<?> target:new Class<?>[]{Float.class,float.class,Integer.class,int.class,Double.class,double.class}){
   Object conv=Proxy.newProxyInstance(lc.getClassLoader(),new Class<?>[]{lc},(proxy,method,values)->{
    if(method.getName().equals("getLuaType"))return Double.class;
    if(method.getName().equals("getJavaType"))return target;
    Number number=(Number)values[0];
    if(target==Float.class||target==float.class)return number.floatValue();
    if(target==Integer.class||target==int.class)return number.intValue();
    return number.doubleValue();
   });
   cm.getMethod("addLuaConverter",lc).invoke(converter,conv);
  }
  for(String type:new String[]{"zombie.entity.components.fluids.FluidContainer","zombie.entity.components.fluids.Fluid","zombie.core.NetTimedAction"}){
   Class<?> cl=c(type);expose.getMethod("setExposed",Class.class).invoke(exposer,cl);
   expose.getMethod("exposeLikeJava",Class.class,table).invoke(exposer,cl,env);
  }
  Class<?> globals=c("zombie.Lua.LuaManager$GlobalObject");
  Method convert=globals.getMethod("convertToPZNetTable",table);
  expose.getMethod("exposeGlobalClassFunction",table,Class.class,Method.class,String.class).invoke(exposer,env,globals,convert,"convertToPZNetTable");
  Object thread=c("se.krka.kahlua.vm.KahluaThread").getConstructor(plat,table).newInstance(p,env);
  thread.getClass().getField("debugOwnerThread").set(thread,Thread.currentThread());
  c("zombie.Lua.LuaManager").getField("thread").set(null,thread);
  c("zombie.Lua.LuaManager").getField("env").set(null,env);
  String code=java.nio.file.Files.readString(java.nio.file.Path.of(args[0]));
  Object closure=c("se.krka.kahlua.luaj.compiler.LuaCompiler").getMethod("loadstring",String.class,String.class,table).invoke(null,code,"service-probe",env);
  Object[] result=(Object[])thread.getClass().getMethod("pcall",Object.class,Object[].class).invoke(thread,closure,new Object[0]);
  for(Object o:result)System.out.println(o);
  if(!Boolean.TRUE.equals(result[0]))System.exit(1);
 }
}
