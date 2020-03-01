/** 增加list文件 */
categories.forEach(({ name, modules, displayName }) => {
  const backgroundPngPath = path.resolve(outputPath, name, "background.png");
  fs.writeFileSync(
    path.resolve(outputPath, name, "README.md"),
    `---
sidebar: false
pageClass: ${name}-page
---    
# ${displayName}
> 模组列表 已收录${modules.length}个模组

<div class="row">
${modules
  .reverse()
  .map(_module => {
    const pic = `./${[_module.name, _module.pic].join("/")}`;
    return `<div class="col-sm-24 col-md-6 col-lg-6 col-xl-4" style="margin-bottom: 15px;text-align: center;">
      <h3 id="${_module.name}">
        <a href="${config.base}module/${name}/${_module.name}">
          <img src="${pic}" />
          <div>${_module.name}</div>
          <div>点击前往</div>
        </a>
      </h3>
    </div>`;
  })
  .join("\n")}
</div>

<style>
  .${name}-page {
    ${
      fs.existsSync(backgroundPngPath)
        ? "background-image: url(./background.png);"
        : ""
    }
    background-color: #ffffff;
    background-repeat: no-repeat;
    background-attachment: fixed;
    background-position: bottom right;
    background-size: 30vmin;
  }  
</style>
`,
    {
      flag: "w"
    }
  );
});

fs.writeFileSync(
  path.resolve(outputPath, "README.md"),
  `
# 根据分类查看
${categories
  .map(
    ({ name, modules, displayName }) => `
## ${displayName}
[点击前往](${config.base}module/${name})
共收录 ${modules.length} 个模组
`
  )
  .join("\n")}
`,
  {
    flag: "w"
  }
);
