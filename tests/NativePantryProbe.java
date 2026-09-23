// Isolated real-game parser/component check; does not start a world or server.
import java.lang.reflect.*;
import java.nio.file.*;
public class NativePantryProbe {
 static Class<?> c(String n)throws Exception{return Class.forName(n);}
 static Object call(Object o,String n,Class<?>[] t,Object...a)throws Exception{return o.getClass().getMethod(n,t).invoke(o,a);}
 public static void main(String[] a)throws Exception {
  Path game=Path.of(a[0]);
  Object module=c("zombie.scripting.objects.ScriptModule").getConstructor().newInstance();
  module.getClass().getField("name").set(module,"Base");
  Class<?> entity=c("zombie.scripting.entity.GameEntityScript"),iso=c("zombie.iso.IsoObject"),ct=c("zombie.entity.ComponentType");
  for(String name:new String[]{"Base.Coffee_Machine","Base.Toaster"}){
   Object script=entity.getConstructor().newInstance();
   call(script,"setModule",new Class[]{c("zombie.scripting.objects.ScriptModule")},module);
   String file=name.endsWith("Toaster")?"entity_toaster.txt":"entity_coffeemachine.txt";
   String body=Files.readString(game.resolve("media/scripts/generated/entities/appliances/workstations/"+file));
   body=body.substring(body.indexOf("entity "),body.lastIndexOf('}'));
   Field scriptName=c("zombie.scripting.objects.BaseScriptObject").getDeclaredField("scriptObjectName");scriptName.setAccessible(true);scriptName.set(script,name.substring(5));
   call(script,"Load",new Class[]{String.class,String.class},name.substring(5),body);
   Object object=iso.getConstructor().newInstance();
   for(String component:new String[]{"CraftBench"}){
    Object type=ct.getField(component).get(null);
    Object def=call(script,"getComponentScriptFor",new Class[]{ct},type);
    if(def==null)throw new AssertionError("missing original component script "+component);
    Object value=call(type,"CreateComponentFromScript",new Class[]{c("zombie.scripting.entity.ComponentScript")},def);
    c("zombie.entity.GameEntityFactory").getMethod("AddComponent",c("zombie.entity.GameEntity"),c("zombie.entity.Component")).invoke(null,object,value);
   }
   Object scriptInfo=call(ct.getField("Script").get(null),"CreateComponent",new Class[]{});
   call(scriptInfo,"setOriginalScript",new Class[]{entity},script);
   c("zombie.entity.GameEntityFactory").getMethod("AddComponent",c("zombie.entity.GameEntity"),c("zombie.entity.Component")).invoke(null,object,scriptInfo);
   for(String component:new String[]{"CraftBench"}){
    Object type=ct.getField(component).get(null);
    Object value=call(object,"getComponent",new Class[]{ct},type);
    if(value==null)throw new AssertionError(name+" missing "+component);
    if(!Boolean.TRUE.equals(call(value,"isValid",new Class[]{})))throw new AssertionError("invalid native bench owner");
    String query=(String)call(value,"getRecipeTagQuery",new Class[]{});
    if(!query.equals(name.endsWith("Toaster")?"Toaster":"CoffeeMachine"))throw new AssertionError("wrong original recipe query "+query);
    System.out.println("PASS "+name+" "+component+" "+value.getClass().getName());
   }
   if(((Number)call(object,"getObjectIndex",new Class[]{})).intValue()!=-1)throw new AssertionError("world object leaked");
   if(call(object,"getEntityScript",new Class[]{})!=script)throw new AssertionError("workstation script identity lost");
   System.out.println("PASS "+name+" original workstation identity and detached object");
  }
 }
}
