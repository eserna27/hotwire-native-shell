// phone({src, placeholder (HTML instead of img), pw, nav:{title, back}, scroll (capture px @3x), frame, tint, cls, style}) -> HTML string
window.phone = function(o){
  const pw=o.pw||1000, bez=pw*0.032, sw=pw-2*bez, k=sw/390;
  const top=(54+(o.nav?44:0))*k, scrollPx=(o.scroll||0)*(sw/1170);
  const sig=`<svg viewBox="0 0 18 12"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5.5" width="3" height="6.5" rx="1"/><rect x="10" y="3" width="3" height="9" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg>`;
  const wifi=`<svg viewBox="0 0 16 12"><path d="M8 2.2c2.4 0 4.6.9 6.2 2.4l1.3-1.4A11 11 0 0 0 8 .2 11 11 0 0 0 .5 3.2l1.3 1.4A9 9 0 0 1 8 2.2zm0 3.6c1.4 0 2.7.5 3.7 1.4l1.3-1.4A7.4 7.4 0 0 0 8 3.8 7.4 7.4 0 0 0 3 5.8l1.3 1.4c1-.9 2.3-1.4 3.7-1.4zM8 9.3l2.2-2.3a3.3 3.3 0 0 0-4.4 0z"/></svg>`;
  const bat=`<svg viewBox="0 0 27 12"><rect x=".5" y=".5" width="23" height="11" rx="3" fill="none" stroke="currentColor" opacity=".4"/><rect x="2" y="2" width="20" height="8" rx="1.8"/><path d="M25 4v4c.8-.3 1.3-1.1 1.3-2S25.8 4.3 25 4z" opacity=".4"/></svg>`;
  const chev=`<svg viewBox="0 0 12 20"><path d="M10 2 2 10l8 8" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
  const nav=o.nav?`<div class="nav">${o.nav.back?`<span class="back">${chev}${o.nav.back===true?'':o.nav.back}</span>`:''}<span class="t">${o.nav.title||''}</span></div>`:'';
  return `<div class="phone ${o.cls||''}" style="--pw:${pw}px;${o.frame?`--frame:${o.frame};`:''}${o.tint?`--tint:${o.tint};`:''}${o.style||''}">
    <div class="scr"><div class="island"></div>
      <div class="sb"><span>${o.time||'9:41'}</span><span class="ic">${sig}${wifi}${bat}</span></div>${nav}
      <div class="web" style="top:${top}px">${o.placeholder?o.placeholder:`<img src="${o.src}" style="margin-top:${-scrollPx}px">`}</div>
      <div class="hi"></div></div></div>`;
};
// tablet({src, placeholder, tw (outer width px), nav:{title, back}, scroll (capture px @2x), date, frame, tint, style}) -> HTML string
window.tablet = function(o){
  const tw=o.tw||1600, tb=tw*0.026, sw=tw-2*tb, k=sw/1032;
  const top=(32+(o.nav?50:0))*k, scrollPx=(o.scroll||0)*(sw/2064);
  const sig=`<svg viewBox="0 0 18 12"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5.5" width="3" height="6.5" rx="1"/><rect x="10" y="3" width="3" height="9" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg>`;
  const wifi=`<svg viewBox="0 0 16 12"><path d="M8 2.2c2.4 0 4.6.9 6.2 2.4l1.3-1.4A11 11 0 0 0 8 .2 11 11 0 0 0 .5 3.2l1.3 1.4A9 9 0 0 1 8 2.2zm0 3.6c1.4 0 2.7.5 3.7 1.4l1.3-1.4A7.4 7.4 0 0 0 8 3.8 7.4 7.4 0 0 0 3 5.8l1.3 1.4c1-.9 2.3-1.4 3.7-1.4zM8 9.3l2.2-2.3a3.3 3.3 0 0 0-4.4 0z"/></svg>`;
  const bat=`<svg viewBox="0 0 27 12"><rect x=".5" y=".5" width="23" height="11" rx="3" fill="none" stroke="currentColor" opacity=".4"/><rect x="2" y="2" width="20" height="8" rx="1.8"/><path d="M25 4v4c.8-.3 1.3-1.1 1.3-2S25.8 4.3 25 4z" opacity=".4"/></svg>`;
  const chev=`<svg viewBox="0 0 12 20"><path d="M10 2 2 10l8 8" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
  const nav=o.nav?`<div class="nav">${o.nav.back?`<span class="back">${chev}</span>`:''}<span class="t">${o.nav.title||''}</span></div>`:'';
  return `<div class="tablet ${o.cls||''}" style="--tw:${tw}px;${o.frame?`--frame:${o.frame};`:''}${o.tint?`--tint:${o.tint};`:''}${o.style||''}">
    <div class="scr"><div class="sb"><span>${o.time||'9:41'}${o.date?'&nbsp;&nbsp;'+o.date:''}</span><span class="ic">${sig}${wifi}${bat}</span></div>${nav}
      <div class="web" style="top:${top}px">${o.placeholder?o.placeholder:`<img src="${o.src}" style="margin-top:${-scrollPx}px">`}</div>
      <div class="hi"></div></div></div>`;
};
