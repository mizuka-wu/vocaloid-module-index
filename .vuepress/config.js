const nav = require("./nav.json");
module.exports = {
  base: "/vocaloid-module-index/",
  title: "V家模组收集",
  themeConfig: {
    // algolia: {
    //   apiKey: '<API_KEY>',
    //   indexName: '<INDEX_NAME>'
    // },
    sidebar: "auto",
    nav: [
      {
        text: "按人物查看",
        items: nav
      },
      {
        text: "切换访问源",
        items: [
          {
            text: "github源",
            link: "https://www.mizuka.top/vocaloid-module-index/"
          },
          {
            text: "gitee源(国内会快)",
            link: "https://mizuka.gitee.io/vocaloid-module-index/"
          }
        ]
      },
      {
        text: "github",
        link: "https://github.com/mizuka-wu/vocaloid-module-index"
      }
    ]
  }
};
