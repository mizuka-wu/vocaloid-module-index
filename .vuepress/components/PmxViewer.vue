<template>
  <div :class="{ fullscreen, pmxviewer: true }">
    <button class="fullscreen-button" @click="fullscreen = !fullscreen">
      点击{{ fullscreen ? "取消" : "" }}全屏
    </button>
    <iframe
      style="border: 0"
      :src="$withBase(src)"
      width="100%"
      height="600"
    ></iframe>
  </div>
</template>

<script>
export default {
  props: {
    path: {
      required: true
    }
  },
  data() {
    return {
      fullscreen: false
    };
  },
  computed: {
    src() {
      const { path } = this;
      return `/pmx/index.html#${path}`;
    }
  }
};
</script>
<style scoped>
.fullscreen {
  position: fixed !important;
  top: 0;
  bottom: 0;
  left: 0;
  right: 0;
  z-index: 9999;
}
.fullscreen-button {
  position: absolute;
  right: 0;
  top: 0;
  z-index: 10000;
}
.pmxviewer {
  position: relative;
}
</style>