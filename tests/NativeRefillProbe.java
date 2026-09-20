// Isolated JVM contract probe. Real game callback/data/items; synthetic recipe
// cache only. No world, server, save, inventory transport or gameplay simulation.
import java.lang.reflect.*;
import java.util.*;
public class NativeRefillProbe {
 static Class<?> c(String n)throws Exception{return Class.forName(n);}
 static Object call(Object o,String name,Class<?>[] sig,Object...args)throws Exception{return o.getClass().getMethod(name,sig).invoke(o,args);}
 static Field field(Class<?> cl,String n)throws Exception{while(cl!=null){try{Field f=cl.getDeclaredField(n);f.setAccessible(true);return f;}catch(NoSuchFieldException e){cl=cl.getSuperclass();}}throw new NoSuchFieldException(n);}
 static void set(Object o,String n,Object v)throws Exception{field(o.getClass(),n).set(o,v);}
 static Object get(Object o,String n)throws Exception{return field(o.getClass(),n).get(o);}
 static Object fresh(String n)throws Exception{Class<?> u=c("sun.misc.Unsafe");Field f=u.getDeclaredField("theUnsafe");f.setAccessible(true);return u.getMethod("allocateInstance",Class.class).invoke(f.get(null),c(n));}
 static Object en(String cl,String name)throws Exception{return c(cl).getField(name).get(null);}
 static Object item(float delta,float used)throws Exception{
  Object i=fresh("zombie.inventory.types.DrainableComboItem");
  call(i,"setUseDelta",new Class<?>[]{float.class},delta);
  call(i,"setCurrentUsesFloat",new Class<?>[]{float.class},used);
  set(i,"conditionMax",10);
  set(i,"condition",7);
  return i;
 }
 static Object script(String kind,boolean keep)throws Exception{
  Object s=fresh("zombie.scripting.entity.components.crafting."+kind);
  set(s,"type",en("zombie.entity.components.resources.ResourceType","Item"));
  set(s,"itemApplyMode",en("zombie.entity.components.crafting.ItemApplyMode",keep?"Keep":"Destroy"));
  return s;
 }
 static Object entry(String kind,Object item,boolean keep)throws Exception{
  Object d=c("zombie.entity.components.crafting.recipe.CraftRecipeData$"+kind+"ScriptData").getConstructor().newInstance();
  set(d,kind.toLowerCase()+"Script",script(kind+"Script",keep));
  ((List<Object>)get(d,"appliedItems")).add(item);return d;
 }
 static void near(double a,double b){if(Math.abs(a-b)>0.00001)throw new AssertionError(a+" != "+b);}
 static void check(float initial,int propane,double factor,double expected,int remaining)throws Exception{
  Object old=item(.1f,initial),out=item(.1f,0),gas=item(.0001f,1);
  call(gas,"setCurrentUses",new Class<?>[]{int.class},propane);
  Class<?> mode=c("zombie.entity.components.crafting.CraftMode");
  Object data=c("zombie.entity.components.crafting.recipe.CraftRecipeData").getConstructor(mode,boolean.class,boolean.class,boolean.class,boolean.class).newInstance(en(mode.getName(),"Handcraft"),true,true,true,true);
  ((List<Object>)get(data,"inputs")).add(entry("Input",old,false));
  ((List<Object>)get(data,"inputs")).add(entry("Input",gas,true));
  ((List<Object>)get(data,"outputs")).add(entry("Output",out,false));
  Field ratio=c("zombie.ZomboidGlobals").getField("refillBlowtorchPropaneAmount");ratio.setDouble(null,factor);
  c("zombie.scripting.logic.RecipeCodeOnCreate").getMethod("refillBlowTorch",data.getClass(),c("zombie.characters.IsoGameCharacter")).invoke(null,data,null);
  near(((Number)call(out,"getCurrentUsesFloat",new Class<?>[]{})).doubleValue(),expected);
  near(((Number)call(gas,"getCurrentUses",new Class<?>[]{})).doubleValue(),remaining);
  near(((Number)call(out,"getCondition",new Class<?>[]{})).doubleValue(),7);
 }
 public static void main(String[] args)throws Exception{
  Object rand=c("zombie.core.random.RandStandard").getField("INSTANCE").get(null);call(rand,"init",new Class<?>[]{});
  check(.25f,10000,70,1,9510);
  check(0,70,70,.1,0);
  check(.25f,10000,35,1,9755);
  System.out.println("PASS native typed refill callback: full, partial, changed global, condition retention");
 }
}
