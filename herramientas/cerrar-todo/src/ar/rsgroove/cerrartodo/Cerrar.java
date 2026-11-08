package ar.rsgroove.cerrartodo;

import android.app.Activity;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.widget.TextView;

/**
 * Muestra «Cerrando todo…»; el cierre lo hace cerrar.sh (root) al ver que esta pantalla se abrió.
 * Sin clases internas: el d8 de build-tools 34 se cae con la clase anónima que arma javac 21.
 */
public class Cerrar extends Activity implements Runnable {
    @Override
    protected void onCreate(Bundle estado) {
        super.onCreate(estado);
        TextView texto = new TextView(this);
        texto.setText("Cerrando todo…");
        texto.setTextSize(36);
        texto.setTextColor(0xFFFFFFFF);
        texto.setBackgroundColor(0xFF101018);
        texto.setGravity(Gravity.CENTER);
        setContentView(texto);
        // Por si cerrar.sh no estuviera corriendo: la pantalla se cierra sola a los 4 s.
        new Handler(Looper.getMainLooper()).postDelayed(this, 4000);
    }

    @Override
    public void run() {
        finish();
    }
}
