/*
  Juegos de las tarjetas de locales.

  Por qué hay tan poco código: la página funciona completa sin este archivo
  (todos los datos y el botón "Cómo llegar" están siempre a la vista).
  Esto solo agrega el "juego" de cada local. Si algo falla acá, la web sigue
  andando; por eso no hay nada importante que dependa de este archivo.

  Cada juego es un botón que prende o apaga una clase en su escena
  ("abierta", "gesto", "prendida"). Las animaciones están en estilos.css.
*/
(function () {
  var clases = { mansion: 'abierta', tercera: 'gesto', '90s': 'prendida' };

  // Actualiza el cartelito de ayuda ("Tocá la puerta" / "Cerrar la puerta").
  function actualizarPista(escena, activo) {
    var pista = escena.querySelector('.escena__pista');
    if (pista) pista.textContent = activo ? pista.dataset.pistaActiva : pista.dataset.pista;
  }

  // La tele de Los 90's: el mapa de Google se crea recién al primer ON.
  // Hasta ese momento no se descarga nada de Google (la página carga más rápido).
  function cargarMapa(escena) {
    var caja = escena.querySelector('.tele__mapa');
    if (!caja || caja.querySelector('iframe')) return;
    var mapa = document.createElement('iframe');
    mapa.src = caja.dataset.mapa;
    mapa.title = 'Mapa: cómo llegar a Burger Couple Los 90\'s, Honduras 5221, Palermo Soho';
    mapa.loading = 'lazy';
    mapa.referrerPolicy = 'no-referrer-when-downgrade';
    caja.appendChild(mapa);
  }

  document.querySelectorAll('[data-juego]').forEach(function (boton) {
    boton.addEventListener('click', function () {
      var juego = boton.dataset.juego;
      var escena = boton.closest('.escena');
      var activo = !escena.classList.contains(clases[juego]);
      if (juego === '90s' && activo) cargarMapa(escena);
      escena.classList.toggle(clases[juego], activo);
      boton.setAttribute('aria-pressed', activo ? 'true' : 'false');
      if (juego === '90s') boton.textContent = activo ? 'OFF' : 'ON';
      actualizarPista(escena, activo);
    });
  });
})();
