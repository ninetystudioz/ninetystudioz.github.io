/* Ninety Construction — app.js = add-ons added after 13 Nov 2026.
   Everything older (the whole app) lives in app-base.js, which index.html loads just before this file.
   app-base.js is only downloaded again when it changes: append new add-ons HERE; touch app-base.js only to patch old code
   (then its ?v=b<sha1[:9]> in index.html and sw.js must change too). See claude/deploy-status.md. */
;(function(){if(window.__NF_TBMIN__)return;window.__NF_TBMIN__=1;const r=document.documentElement,n=window.matchMedia?window.matchMedia("(max-width:900px)"):{matches:!1};try{if(!(window.CSS&&CSS.supports&&CSS.supports("inset-inline-start","0")))return}catch{return}try{(document.head||r).insertAdjacentHTML("beforeend",`<style id="nf-tbmin">
@media (max-width:900px){
  @media (prefers-reduced-motion:no-preference){
    html.nf-tbm .tabbar{transition:left .26s cubic-bezier(.2,.8,.2,1),right .26s cubic-bezier(.2,.8,.2,1),height .2s ease,border-radius .2s ease,bottom .2s ease,padding .2s ease}
    html.nf-tbm .tabbar>a{transition:opacity .16s ease .06s}
    html.nf-tbmin .tabbar>a{transition:opacity .08s ease}
    html.nf-tbm .nfdial .nfd-main{transition:transform .22s ease,bottom .26s cubic-bezier(.2,.8,.2,1)}
  }
  html.nf-tbm.nf-tbmin .nfdial .nfd-main{bottom:calc(11px + env(safe-area-inset-bottom,0px))!important}
  html.nf-tbm.nf-tbmin .tabbar.tabbar.tabbar{height:56px!important;padding:0!important;border-radius:28px!important;bottom:calc(10px + env(safe-area-inset-bottom,0px))!important;border:1px solid var(--line)!important;box-shadow:0 10px 26px -12px rgba(20,30,50,.45)!important;overflow:hidden!important;cursor:pointer}
  html[dir=rtl].nf-tbm.nf-tbmin .tabbar.tabbar.tabbar{inset-inline-start:12px!important;inset-inline-end:calc(100% - 68px)!important}
  html:not([dir=rtl]).nf-tbm.nf-tbmin .tabbar.tabbar.tabbar{inset-inline-end:12px!important;inset-inline-start:calc(100% - 68px)!important}
  html.nf-tbmin .tabbar.tabbar>a{position:absolute!important;inset:0!important;margin:0!important;padding:0!important;opacity:0!important;pointer-events:none!important;border-radius:28px!important;flex:none!important}
  html.nf-tbmin .tabbar.tabbar>a.on,html.nf-tbmin.nf-tbmore .tabbar.tabbar>a[data-action="openside"]{opacity:1!important}
  html.nf-tbmin .tabbar.tabbar>a>span,html.nf-tbmin .tabbar.tabbar>a>.cnt{display:none!important}
  html.nf-tbmin .tabbar.tabbar>a>svg{width:24px!important;height:24px!important}
}
</style>`)}catch{return}r.classList.add("nf-tbm");let a=!1,m=0,o=0,s=0,d=0,c=!1,p=0,f=0;const u=()=>document.querySelector(".tabbar"),l=()=>{try{const t=u();r.classList.toggle("nf-tbmore",!(t&&t.querySelector(":scope > a.on")))}catch{}};function e(t){t=!!t&&!!n.matches,o=0,s=0,t!==a&&(a=t,t&&l(),r.classList.toggle("nf-tbmin",t))}const h=()=>window.scrollY||r.scrollTop||0;function w(){d=0;const t=h(),i=t-m;if(m=t,!n.matches){a&&e(!1);return}if(t<56){e(!1);return}(c||Date.now()-p<1500)&&(i>0?(o+=i,s=0,o>24&&Date.now()-f>2500&&e(!0)):i<0&&(s-=i,o=0,s>40&&e(!1)))}window.addEventListener("scroll",()=>{d||(d=requestAnimationFrame(w))},{passive:!0});const b=()=>{p=Date.now()};window.addEventListener("touchstart",()=>{c=!0,b()},{passive:!0,capture:!0}),["touchend","touchcancel"].forEach(t=>window.addEventListener(t,()=>{c=!1,b()},{passive:!0,capture:!0})),window.addEventListener("wheel",b,{passive:!0,capture:!0}),window.addEventListener("keydown",t=>{/^(Arrow|Page|Home|End| $)/.test(t.key||"")&&b()},!0),document.addEventListener("click",t=>{!a||!(t.target&&t.target.closest&&t.target.closest(".tabbar"))||(t.preventDefault(),t.stopPropagation(),f=Date.now(),e(!1))},!0),window.addEventListener("hashchange",()=>{m=0,e(!1)});try{n.addEventListener?n.addEventListener("change",()=>e(!1)):n.addListener&&n.addListener(()=>e(!1))}catch{}try{typeof RENDER_HOOKS!="undefined"&&RENDER_HOOKS.push(()=>{a&&l()})}catch{}window.nfTabbarMin={set:e,is:()=>a}})();
