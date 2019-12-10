// All Rust lines starting with `# ` get the `.cs` (comment-special)
// class. Remove them as they are only needed to make `rustdoc` happy.
document.querySelectorAll('.language-rust pre > code .cs').forEach(function (el) {
  el.parentElement.removeChild(el);
});
