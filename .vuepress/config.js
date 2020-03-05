const fs = require("fs");
const path = require("path");
const { ROLE_NAME } = require("./const");

const modules = fs
  .readdirSync(path.resolve("module"))
  .filter(moduleName =>
    fs.statSync(path.resolve("module", moduleName)).isDirectory()
  )
  .map(moduleName => ({
    text: ROLE_NAME[moduleName] || moduleName,
    link: `/module/${moduleName}/`
  }))
  .sort((prev, next) => {
    return prev.name > next.name ? 1 : -1;
  });

module.exports = {
  base: "/vocaloid-module-index/",
  title: "V家模组收集",
  themeConfig: {
    sidebar: "auto",
    sidebarDepth: 2,
    lastUpdated: "最后更新时间 ",
    algolia: {
      apiKey: "1c71a0c7c33f8f8050e8493037a17f64",
      indexName: "vocaloid-module-index"
    },
    displayAllHeaders: true,
    nav: [
      {
        text: "按人物查看",
        items: modules
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
  },
  plugins: [
    require("./plugins/module-index.js"),
    "vuepress-plugin-baidu-autopush",
    [
      "@vuepress/google-analytics",
      {
        ga: "UA-112738831-2" // UA-00000000-0
      }
    ],
    ["sitemap", { hostname: "https://mizuka.gitee.io/vocaloid-module-index/" }],
    [
      "vuepress-plugin-medium-zoom",
      {
        selector: "img",
        delay: 1000,
        options: {
          margin: 24,
          background: "#000000",
          scrollOffset: 0
        }
      }
    ]
  ]
};
