import lume from "lume/mod.ts";
import code_highlight from "lume/plugins/code_highlight.ts";
import nav from "lume/plugins/nav.ts";
import search from "lume/plugins/search.ts";
import sitemap from "lume/plugins/sitemap.ts";

const site = lume({
  src: ".",
  dest: "_site",
  location: new URL("https://windsurf-project.dev"),
});

site.use(code_highlight());
site.use(nav());
site.use(search());
site.use(sitemap());

site.copy("assets");

export default site;
