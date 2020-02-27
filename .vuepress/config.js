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
            link: "https://mizuka.gitee.io/vocaloid-module-index/"
          }
        ]
      }
    ]
  }
};
