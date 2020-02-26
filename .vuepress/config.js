const nav = require("./nav.json");
module.exports = {
  base: "/vocaloid-module-index/",
  title: "V家模组收集",
  evergreen: true,
  themeConfig: {
    nav: [
      {
        text: "分类",
        items: nav
      }
    ]
  }
};
