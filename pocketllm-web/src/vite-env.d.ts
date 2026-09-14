/// <reference types="vite/client" />
/// <reference types="vite-plugin-pwa/client" />

declare module "*?url" {
  const url: string;
  export default url;
}
