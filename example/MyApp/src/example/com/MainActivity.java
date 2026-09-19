package example.com;
import android.app.Activity;
import android.os.Bundle;
import android.widget.Button;
import android.view.View;
import android.widget.Toast;
public class MainActivity extends Activity{
protected void onCreate(Bundle s){
super.onCreate(s);
setContentView(R.layout.activity_main);
((Button)findViewById(R.id.b)).setOnClickListener(new View.OnClickListener(){
public void onClick(View v){
Toast.makeText(MainActivity.this,"Hi",0).show();
}});}}
