// Runs with the installed game JRE/JAR. Isolated Lua environment, real Vector2
// and game Exposer; numeric return conversion installed without booting a server.
import java.lang.reflect.*;
public class NativeVectorProbe {
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
  Class<?> vec=c("zombie.iso.Vector2");
  expose.getMethod("setExposed",Class.class).invoke(exposer,vec);
  expose.getMethod("exposeLikeJava",Class.class,table).invoke(exposer,vec,env);
  Object center=vec.getConstructor(float.class,float.class).newInstance(10.75f,-2.25f);
  table.getMethod("rawset",Object.class,Object.class).invoke(env,"nativeCenter",center);
  Object thread=c("se.krka.kahlua.vm.KahluaThread").getConstructor(plat,table).newInstance(p,env);
  thread.getClass().getField("debugOwnerThread").set(thread,Thread.currentThread());
  String code=java.nio.file.Files.readString(java.nio.file.Path.of(args[0]));
  Object closure=c("se.krka.kahlua.luaj.compiler.LuaCompiler").getMethod("loadstring",String.class,String.class,table).invoke(null,code,"vector-probe",env);
  Object[] result=(Object[])thread.getClass().getMethod("pcall",Object.class,Object[].class).invoke(thread,closure,new Object[0]);
  for(Object o:result)System.out.println(o);
  if(!Boolean.TRUE.equals(result[0]))System.exit(1);
 }
}
