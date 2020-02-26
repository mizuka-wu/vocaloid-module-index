const nav = require("./nav.json");
module.exports = {
  base: "/vocaloid-module-index/",
  title: "V家模组收集",
  themeConfig: {
    nav: [
      {
        text: "分类",
        items: nav
      },
      {
        text: "源",
        items: [
          {
            text: "github源",
            link: "https://www.mizuka.top/vocaloid-module-index/"
          },
          {
            text: "gitee源",
            link: "https://miuzka.gitee.io/vocaloid-module-index/"
          }
        ]
      }
    ]
  }
};
