public class PrintMRJobConfig {
  public static void main(String[] args) throws Exception {
    Class<?> c = Class.forName("org.apache.hadoop.mapreduce.MRJobConfig");
    for (String n : new String[]{"MR_AM_ADMIN_USER_ENV","DEFAULT_MR_AM_ADMIN_USER_ENV","MAPRED_ADMIN_USER_ENV","DEFAULT_MAPRED_ADMIN_USER_ENV"}) {
      java.lang.reflect.Field f = c.getField(n);
      System.out.println(n + "=" + f.get(null));
    }
  }
}
