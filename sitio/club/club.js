/*
  Lógica de las páginas del club (registro, mi cuenta, caja y cambio de contraseña).

  Reglas que se respetan acá, y por qué:
  * La web NUNCA calcula ni decide puntos: le manda al servidor el monto de la
    compra y muestra lo que el servidor contesta. Así nadie puede "trucharlos"
    tocando la página desde su celular.
  * Los mensajes de error se muestran tal cual los dice el servidor, en
    castellano y sin chistes (pagos, puntos y errores se escriben literales).
  * Cada carga de compra o canje lleva un identificador único ("referencia")
    que se crea al preparar la operación: si el cajero toca dos veces o se
    corta internet y reintenta, el servidor la cuenta una sola vez.
*/
(function () {
  'use strict';

  var cfg = window.CLUB_CONFIG || {};
  var conectado = cfg.supabaseUrl && cfg.supabaseUrl !== 'PENDIENTE' && window.supabase;
  var sb = conectado ? window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseClave) : null;

  var NIVELES = {
    'pelo-crocante': { nombre: 'Pelo Crocante', beneficio: 'Sumás 10 puntos por cada $1.000.' },
    'tomasito': { nombre: 'Tomasito', beneficio: 'Sumás un 10% más de puntos en cada compra.' },
    'comandante': { nombre: 'Comandante', beneficio: 'Sumás un 25% más de puntos y tenés un premio exclusivo.' }
  };

  // ---------- utilidades ----------
  function $(sel, raiz) { return (raiz || document).querySelector(sel); }
  function $$(sel, raiz) { return Array.prototype.slice.call((raiz || document).querySelectorAll(sel)); }
  function pesos(n) { return '$' + Math.round(Number(n) || 0).toLocaleString('es-AR'); }
  function numero(n) { return (Number(n) || 0).toLocaleString('es-AR'); }
  function fecha(iso) {
    return new Date(iso).toLocaleDateString('es-AR', { day: 'numeric', month: 'long', year: 'numeric' });
  }
  function referenciaNueva() {
    if (window.crypto && crypto.randomUUID) return crypto.randomUUID();
    // Respaldo para navegadores viejos.
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
      var r = Math.random() * 16 | 0; return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
    });
  }
  function mensaje(caja, texto, tipo) {
    if (!caja) return;
    caja.textContent = texto || '';
    caja.className = 'mensaje' + (texto ? ' mensaje--' + (tipo || 'info') : '');
  }
  // Traduce los errores más comunes de Supabase a un castellano claro.
  function errorLegible(e) {
    var m = (e && (e.message || e.error_description)) || String(e);
    if (/Invalid login credentials/i.test(m)) return 'El mail o la contraseña no coinciden.';
    if (/Email not confirmed/i.test(m)) return 'Todavía no confirmaste tu mail. Revisá tu casilla (y la carpeta de spam).';
    if (/User already registered/i.test(m)) return 'Ya existe una cuenta con ese mail. Probá entrar o recuperar la contraseña.';
    if (/Password should be at least/i.test(m)) return 'La contraseña tiene que tener al menos 8 caracteres.';
    if (/rate limit/i.test(m)) return 'Hubo demasiados intentos seguidos. Esperá unos minutos y probá de nuevo.';
    if (/Failed to fetch|NetworkError/i.test(m)) return 'No hay conexión. Revisá internet y probá de nuevo.';
    return m;
  }
  function avisoSinConexion() {
    $$('[data-requiere-conexion]').forEach(function (el) { el.hidden = true; });
    var aviso = $('#aviso-sin-conexion'); if (aviso) aviso.hidden = false;
  }
  function base() { return location.origin; }

  // ---------- premios (se leen de la base; si no hay conexión, queda la lista escrita en la página) ----------
  function cargarPremios(lista, saldo, nivel) {
    if (!sb || !lista) return Promise.resolve([]);
    return sb.from('premios').select('id,nombre,puntos,solo_nivel').order('orden').then(function (r) {
      if (r.error || !r.data) return [];
      lista.innerHTML = '';
      r.data.forEach(function (p) {
        var li = document.createElement('li');
        li.className = 'premio';
        var exclusivo = p.solo_nivel ? ' <span class="capsula">Solo ' + NIVELES[p.solo_nivel].nombre + '</span>' : '';
        var estado = '';
        if (typeof saldo === 'number') {
          var bloqueado = p.solo_nivel === 'comandante' && nivel !== 'comandante';
          estado = bloqueado ? '<span class="premio__estado">Exclusivo de otro nivel</span>'
            : saldo >= p.puntos ? '<span class="premio__estado premio__estado--listo">¡Ya lo podés canjear!</span>'
            : '<span class="premio__estado">Te faltan ' + numero(p.puntos - saldo) + ' puntos</span>';
        }
        li.innerHTML = '<span class="premio__puntos">' + numero(p.puntos) + '<small>pts</small></span>' +
          '<span class="premio__nombre"></span>' + exclusivo + estado;
        li.querySelector('.premio__nombre').textContent = p.nombre;
        lista.appendChild(li);
      });
      return r.data;
    });
  }

  // =====================================================================
  //  Página: /club/ (registro y entrada)
  // =====================================================================
  function paginaInicio() {
    cargarPremios($('#lista-premios'));
    if (!sb) { avisoSinConexion(); return; }

    // Si ya tiene sesión, directo a su tarjeta.
    sb.auth.getSession().then(function (r) { if (r.data.session) location.href = '/club/mi-cuenta.html'; });

    // Pestañas "Crear cuenta" / "Entrar".
    $$('[data-pestana]').forEach(function (b) {
      b.addEventListener('click', function () {
        $$('[data-pestana]').forEach(function (x) { x.setAttribute('aria-selected', x === b ? 'true' : 'false'); });
        $$('[data-panel]').forEach(function (p) { p.hidden = p.dataset.panel !== b.dataset.pestana; });
      });
    });

    $('#form-registro').addEventListener('submit', function (ev) {
      ev.preventDefault();
      var f = ev.target, caja = $('#msg-registro');
      if (!f.bases.checked) { mensaje(caja, 'Para sumarte tenés que aceptar las bases y condiciones.', 'error'); return; }
      f.querySelector('button').disabled = true;
      mensaje(caja, 'Creando tu cuenta…');
      sb.auth.signUp({
        email: f.email.value.trim(),
        password: f.password.value,
        options: {
          data: { nombre: f.nombre.value.trim(), acepta_bases: 'true' },
          emailRedirectTo: base() + '/club/mi-cuenta.html'
        }
      }).then(function (r) {
        f.querySelector('button').disabled = false;
        if (r.error) { mensaje(caja, errorLegible(r.error), 'error'); return; }
        if (r.data.session) { location.href = '/club/mi-cuenta.html'; return; }
        mensaje(caja, '¡Listo! Te mandamos un mail a ' + f.email.value.trim() + '. Abrilo y tocá el link para activar tu cuenta.', 'ok');
        f.reset();
      });
    });

    $('#form-entrar').addEventListener('submit', function (ev) {
      ev.preventDefault();
      var f = ev.target, caja = $('#msg-entrar');
      f.querySelector('button').disabled = true;
      mensaje(caja, 'Entrando…');
      sb.auth.signInWithPassword({ email: f.email.value.trim(), password: f.password.value }).then(function (r) {
        f.querySelector('button').disabled = false;
        if (r.error) { mensaje(caja, errorLegible(r.error), 'error'); return; }
        location.href = '/club/mi-cuenta.html';
      });
    });

    $('#boton-olvide').addEventListener('click', function () {
      var f = $('#form-entrar'), caja = $('#msg-entrar'), email = f.email.value.trim();
      if (!email) { mensaje(caja, 'Escribí tu mail arriba y volvé a tocar "Me olvidé la contraseña".', 'error'); return; }
      sb.auth.resetPasswordForEmail(email, { redirectTo: base() + '/club/restablecer.html' }).then(function (r) {
        if (r.error) { mensaje(caja, errorLegible(r.error), 'error'); return; }
        mensaje(caja, 'Si ese mail tiene cuenta, te llega un link para elegir una contraseña nueva.', 'ok');
      });
    });
  }

  // =====================================================================
  //  Página: /club/mi-cuenta.html (la tarjeta del socio)
  // =====================================================================
  function paginaMiCuenta() {
    if (!sb) { avisoSinConexion(); return; }
    sb.auth.getSession().then(function (r) {
      if (!r.data.session) { location.href = '/club/'; return; }
      return sb.rpc('mi_resumen').then(function (res) {
        if (res.error) { mensaje($('#msg-cuenta'), errorLegible(res.error), 'error'); return; }
        pintarTarjeta(res.data);
        cargarPremios($('#lista-premios'), res.data.saldo, res.data.nivel);
        return sb.from('movimientos').select('tipo,puntos,monto_pesos,motivo,creado_at,local_id')
          .order('creado_at', { ascending: false }).limit(50).then(pintarHistorial);
      });
    });
    $('#boton-salir').addEventListener('click', function () {
      sb.auth.signOut().then(function () { location.href = '/club/'; });
    });
  }

  function pintarTarjeta(d) {
    var nivel = NIVELES[d.nivel] || NIVELES['pelo-crocante'];
    var tarjeta = $('#tarjeta');
    tarjeta.dataset.nivel = d.nivel;
    $('#t-nombre').textContent = d.nombre || d.email;
    $('#t-nivel').textContent = nivel.nombre;
    $('#t-beneficio').textContent = nivel.beneficio;
    $('#t-saldo').textContent = numero(d.saldo);
    $('#t-codigo').textContent = d.codigo;
    $('#t-vence').textContent = d.vencen_el
      ? 'Tus puntos vencen el ' + fecha(d.vencen_el) + ' si no volvés a comprar antes. Cada compra corre la fecha 3 meses.'
      : 'Tu primera compra suma el doble de puntos.';
    // Barra de progreso hacia el nivel siguiente.
    var meta = d.nivel === 'pelo-crocante' ? 60000 : d.nivel === 'tomasito' ? 150000 : 0;
    var progreso = $('#t-progreso');
    if (meta) {
      var pct = Math.min(100, Math.round(d.gasto_90_dias / meta * 100));
      progreso.querySelector('.progreso__barra span').style.width = pct + '%';
      progreso.querySelector('.progreso__texto').textContent = 'Te faltan ' + pesos(d.falta_siguiente_nivel) +
        ' en los próximos 3 meses para ser ' + (d.nivel === 'pelo-crocante' ? 'Tomasito' : 'Comandante') + '.';
    } else {
      progreso.querySelector('.progreso__barra span').style.width = '100%';
      progreso.querySelector('.progreso__texto').textContent = 'Estás en el nivel más alto. Respeto.';
    }
    // QR con el código de socio: es lo que escanea el cajero.
    if (window.qrcode) {
      var qr = window.qrcode(0, 'M');
      qr.addData(d.codigo);
      qr.make();
      $('#t-qr').innerHTML = qr.createSvgTag({ cellSize: 6, margin: 2, scalable: true });
    }
  }

  function pintarHistorial(r) {
    var lista = $('#historial');
    if (r.error || !r.data || !r.data.length) { lista.innerHTML = '<li class="historial__vacio">Todavía no tenés movimientos. Mostrá tu QR en tu próxima compra.</li>'; return; }
    var nombres = { compra: 'Compra', canje: 'Canje', vencimiento: 'Vencimiento', ajuste: 'Ajuste' };
    lista.innerHTML = '';
    r.data.forEach(function (m) {
      var li = document.createElement('li');
      li.className = 'historial__item historial__item--' + m.tipo;
      var detalle = m.tipo === 'compra' ? pesos(m.monto_pesos) + (m.motivo ? ' · ' + m.motivo : '') : (m.motivo || '');
      li.innerHTML = '<span class="historial__fecha"></span><span class="historial__tipo"></span>' +
        '<span class="historial__detalle"></span><span class="historial__puntos"></span>';
      li.querySelector('.historial__fecha').textContent = fecha(m.creado_at);
      li.querySelector('.historial__tipo').textContent = nombres[m.tipo] || m.tipo;
      li.querySelector('.historial__detalle').textContent = detalle;
      li.querySelector('.historial__puntos').textContent = (m.puntos > 0 ? '+' : '') + numero(m.puntos);
      lista.appendChild(li);
    });
  }

  // =====================================================================
  //  Página: /club/restablecer.html (contraseña nueva)
  // =====================================================================
  function paginaRestablecer() {
    if (!sb) { avisoSinConexion(); return; }
    $('#form-restablecer').addEventListener('submit', function (ev) {
      ev.preventDefault();
      var f = ev.target, caja = $('#msg-restablecer');
      if (f.password.value !== f.password2.value) { mensaje(caja, 'Las dos contraseñas no coinciden.', 'error'); return; }
      sb.auth.updateUser({ password: f.password.value }).then(function (r) {
        if (r.error) { mensaje(caja, errorLegible(r.error), 'error'); return; }
        mensaje(caja, 'Listo, ya tenés contraseña nueva. Te llevamos a tu tarjeta…', 'ok');
        setTimeout(function () { location.href = '/club/mi-cuenta.html'; }, 1500);
      });
    });
  }

  // =====================================================================
  //  Página: /club/caja.html (panel del personal)
  // =====================================================================
  var caja = { socio: null, codigo: null, refCompra: null, local: null, personal: null };

  function paginaCaja() {
    if (!sb) { avisoSinConexion(); return; }
    sb.auth.getSession().then(function (r) {
      if (r.data.session) iniciarPanel(); else { $('#caja-login').hidden = false; }
    });

    $('#caja-login').addEventListener('submit', function (ev) {
      ev.preventDefault();
      var f = ev.target, msg = $('#msg-caja-login');
      sb.auth.signInWithPassword({ email: f.email.value.trim(), password: f.password.value }).then(function (r) {
        if (r.error) { mensaje(msg, errorLegible(r.error), 'error'); return; }
        iniciarPanel();
      });
    });
    $('#boton-caja-salir').addEventListener('click', function () {
      sb.auth.signOut().then(function () { location.reload(); });
    });

    $('#form-codigo').addEventListener('submit', function (ev) {
      ev.preventDefault();
      buscarSocio(ev.target.codigo.value);
    });
    $('#boton-escanear').addEventListener('click', escanear);
    $('#boton-otro-socio').addEventListener('click', limpiarSocio);

    $('#form-compra').addEventListener('submit', function (ev) {
      ev.preventDefault();
      var monto = Number(String(ev.target.monto.value).replace(/[^\d]/g, ''));
      var msg = $('#msg-compra');
      if (!monto) { mensaje(msg, 'Escribí el monto total de la compra.', 'error'); return; }
      // Confirmación con el monto bien grande: un cero de más es el error más común.
      if (!confirm('¿Cargar una compra de ' + pesos(monto) + ' a ' + (caja.socio.nombre || caja.codigo) + '?')) return;
      ev.target.querySelector('button').disabled = true;
      mensaje(msg, 'Cargando…');
      sb.rpc('registrar_compra', { p_codigo: caja.codigo, p_monto: monto, p_local: caja.local, p_referencia: caja.refCompra })
        .then(function (r) {
          ev.target.querySelector('button').disabled = false;
          if (r.error) { mensaje(msg, errorLegible(r.error), 'error'); return; }
          var d = r.data;
          mensaje(msg, d.repetida ? 'Esta compra ya estaba cargada: no se sumó de nuevo.'
            : '✅ Se sumaron ' + numero(d.puntos) + ' puntos' + (d.primera_compra ? ' (primera compra: doble)' : '') + '.', d.repetida ? 'info' : 'ok');
          ev.target.reset();
          caja.refCompra = referenciaNueva(); // la próxima compra es otra operación
          mostrarSocio(d.resumen);
        });
    });

    $('#form-alta').addEventListener('submit', function (ev) {
      ev.preventDefault();
      var f = ev.target, msg = $('#msg-alta');
      sb.rpc('alta_personal', { p_email: f.email.value.trim(), p_nombre: f.nombre.value.trim(), p_rol: f.rol.value, p_local: f.local.value })
        .then(function (r) { mensaje(msg, r.error ? errorLegible(r.error) : 'Listo: ya puede usar el panel de caja.', r.error ? 'error' : 'ok'); if (!r.error) f.reset(); });
    });
    $('#form-baja').addEventListener('submit', function (ev) {
      ev.preventDefault();
      var f = ev.target, msg = $('#msg-baja');
      if (!confirm('¿Quitarle el acceso a la caja a ' + f.email.value.trim() + '?')) return;
      sb.rpc('baja_personal', { p_email: f.email.value.trim() })
        .then(function (r) { mensaje(msg, r.error ? errorLegible(r.error) : 'Listo: ya no puede usar la caja.', r.error ? 'error' : 'ok'); if (!r.error) f.reset(); });
    });
  }

  function iniciarPanel() {
    sb.auth.getUser().then(function (u) {
      return sb.from('personal').select('nombre,rol,local_id,activo').eq('id', u.data.user.id).maybeSingle();
    }).then(function (r) {
      if (!r.data || !r.data.activo) {
        $('#caja-login').hidden = false;
        mensaje($('#msg-caja-login'), 'Tu cuenta existe, pero no está habilitada para la caja. Pedíselo a un administrador.', 'error');
        return;
      }
      caja.personal = r.data;
      $('#caja-login').hidden = true;
      $('#caja-panel').hidden = false;
      $('#caja-quien').textContent = r.data.nombre + (r.data.rol === 'admin' ? ' (administrador)' : '');
      if (r.data.rol === 'admin') $('#caja-admin').hidden = false;
      // El local se recuerda en este dispositivo: la tablet de un local casi siempre es del mismo local.
      var guardado = null;
      try { guardado = localStorage.getItem('bc-caja-local'); } catch (e) { /* sin almacenamiento: no pasa nada */ }
      var selector = $('#caja-local');
      selector.value = guardado || r.data.local_id || selector.value;
      caja.local = selector.value;
      selector.addEventListener('change', function () {
        caja.local = selector.value;
        try { localStorage.setItem('bc-caja-local', selector.value); } catch (e) { /* idem */ }
      });
    });
  }

  function buscarSocio(codigo) {
    var msg = $('#msg-socio');
    codigo = String(codigo || '').toUpperCase().replace(/\s/g, '');
    if (!codigo) return;
    mensaje(msg, 'Buscando…');
    sb.rpc('buscar_socio', { p_codigo: codigo }).then(function (r) {
      if (r.error) { mensaje(msg, errorLegible(r.error), 'error'); return; }
      mensaje(msg, '');
      caja.codigo = codigo;
      caja.refCompra = referenciaNueva();
      mostrarSocio(r.data);
    });
  }

  function mostrarSocio(d) {
    caja.socio = d;
    $('#paso-buscar').hidden = true;
    $('#paso-socio').hidden = false;
    $('#s-nombre').textContent = d.nombre || d.email;
    $('#s-codigo').textContent = d.codigo;
    $('#s-nivel').textContent = (NIVELES[d.nivel] || {}).nombre || d.nivel;
    $('#s-saldo').textContent = numero(d.saldo);
    // Premios canjeables con un botón cada uno.
    sb.from('premios').select('id,nombre,puntos,solo_nivel').order('orden').then(function (r) {
      var lista = $('#s-premios');
      lista.innerHTML = '';
      (r.data || []).forEach(function (p) {
        var li = document.createElement('li');
        var boton = document.createElement('button');
        boton.type = 'button';
        boton.className = 'boton boton--chico ' + (d.saldo >= p.puntos ? 'boton--amarillo' : 'boton--apagado');
        boton.disabled = d.saldo < p.puntos || (p.solo_nivel === 'comandante' && d.nivel !== 'comandante');
        boton.textContent = 'Canjear';
        boton.addEventListener('click', function () { canjear(p); });
        li.innerHTML = '<span class="premio__puntos">' + numero(p.puntos) + '<small>pts</small></span> <span class="premio__nombre"></span>';
        li.querySelector('.premio__nombre').textContent = p.nombre;
        li.appendChild(boton);
        lista.appendChild(li);
      });
    });
  }

  function canjear(p) {
    var msg = $('#msg-canje');
    if (!confirm('¿Canjear "' + p.nombre + '" por ' + numero(p.puntos) + ' puntos?')) return;
    sb.rpc('canjear_premio', { p_codigo: caja.codigo, p_premio: p.id, p_local: caja.local, p_referencia: referenciaNueva() })
      .then(function (r) {
        if (r.error) { mensaje(msg, errorLegible(r.error), 'error'); return; }
        mensaje(msg, '✅ Canjeado: ' + r.data.premio + '. Entregale el premio.', 'ok');
        mostrarSocio(r.data.resumen);
      });
  }

  function limpiarSocio() {
    caja.socio = null; caja.codigo = null; caja.refCompra = null;
    $('#paso-socio').hidden = true;
    $('#paso-buscar').hidden = false;
    $('#form-codigo').reset();
    ['#msg-socio', '#msg-compra', '#msg-canje'].forEach(function (s) { mensaje($(s), ''); });
  }

  // Escáner con la cámara: se prende solo cuando el cajero lo pide y se apaga
  // apenas lee un código (así no queda la cámara encendida gastando batería).
  function escanear() {
    var video = $('#camara'), marco = $('#marco-camara'), msg = $('#msg-socio');
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia || !window.jsQR) {
      mensaje(msg, 'Este dispositivo no permite usar la cámara acá. Escribí el código a mano.', 'error'); return;
    }
    navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } }).then(function (stream) {
      marco.hidden = false;
      video.srcObject = stream;
      video.play();
      var lienzo = document.createElement('canvas'), ctx = lienzo.getContext('2d', { willReadFrequently: true });
      var apagar = function () { stream.getTracks().forEach(function (t) { t.stop(); }); marco.hidden = true; };
      $('#boton-cerrar-camara').onclick = apagar;
      (function mirar() {
        if (marco.hidden) return;
        if (video.readyState === video.HAVE_ENOUGH_DATA) {
          lienzo.width = video.videoWidth; lienzo.height = video.videoHeight;
          ctx.drawImage(video, 0, 0);
          var img = ctx.getImageData(0, 0, lienzo.width, lienzo.height);
          var leido = window.jsQR(img.data, img.width, img.height, { inversionAttempts: 'dontInvert' });
          if (leido && /^BC[A-Z0-9]{6}$/.test(leido.data.trim().toUpperCase())) {
            apagar();
            buscarSocio(leido.data);
            return;
          }
        }
        requestAnimationFrame(mirar);
      })();
    }).catch(function () {
      mensaje(msg, 'No se pudo abrir la cámara (¿falta dar permiso?). Escribí el código a mano.', 'error');
    });
  }

  // ---------- arranque según la página ----------
  var pagina = document.body.dataset.pagina;
  if (pagina === 'inicio') paginaInicio();
  if (pagina === 'mi-cuenta') paginaMiCuenta();
  if (pagina === 'restablecer') paginaRestablecer();
  if (pagina === 'caja') paginaCaja();
})();
