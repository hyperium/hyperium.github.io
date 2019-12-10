// All Rust lines starting with `# ` get the `.cs` (comment-special)
// class. Remove them as they are only needed to make `rustdoc` happy.
document.querySelectorAll('.language-rust pre > code').forEach(function (el) {
  var s = el.innerHTML.replace(/<span class="cs">#\s.*\n/g, '');
  el.innerHTML = s;
});
