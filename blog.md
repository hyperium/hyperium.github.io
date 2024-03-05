---
layout: default
permalink: /blog
---

<div class="blog archive">

    <ul class="post-list">
    {% for post in site.posts %}
        <li>
            <h2 class="post-title">
                <a class="post-link" href="{{ post.url | prepend: site.baseurl }}">{{ post.title }}</a>
            </h2>
        </li>
    {% endfor %}
    </ul>

</div>
