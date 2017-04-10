document.querySelectorAll('pre > code').forEach(function (el) {
  el.innerHTML = el.innerHTML.replace(/#\s.*\n/g, '');
});
