<template>
  <div>
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
  computed: {
    src() {
      const { path } = this;
      return `/pmx/index.html#${path}`;
    }
  }
};
</script>