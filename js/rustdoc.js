document.querySelectorAll('pre > code').forEach(function (el) {
  var s = el.innerHTML.replace(/#\s.*\n/g, '');
  s = s.replace(/<span class="err">#<\/span>\s.*\n/g, '');
  el.innerHTML = s;
});
