// Mirrors BuddyArt.draw in Sources/PaperTree/BuddyView.swift so previews match the app.
function buddySVG({research=false, mood='idle', t=0.0, size=200, id='b'} = {}) {
  const C = {mintGlass:'#D9F3E1', mintLight:'#C4ECD0', mint:'#9FDDB4', mintDeep:'#6FBF8E', mintLine:'#4F9A6C',
             haloPink:'#F4C4E4', haloLilac:'#DCCBF6', blush:'#F5A9C8', red:'#B2432C'};
  const thinking = mood==='thinking', noticed = mood==='noticed';
  const pulse = research ? (Math.sin(t*2.4)*0.5+0.5) : 0;
  const haloR = research ? 47 + pulse*2 : 42;
  const ha = research ? 0.95 : 0.7;
  const bob = Math.sin(t*2.1)*1.6 + (noticed ? -Math.abs(Math.sin(t*6))*2.2 : 0);
  const body = 'M41 21 L41 42 L21.5 77 Q16 90 29 90 L71 90 Q84 90 78.5 77 L59 42 L59 21 Z';
  const eyeY=70, eyeL=41.5, eyeR=58.5;
  let s = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="${size}" height="${size}">
  <defs>
    <radialGradient id="${id}h" cx="50" cy="56" r="${haloR}" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="${C.haloPink}" stop-opacity="${ha}"/>
      <stop offset="0.45" stop-color="${C.haloPink}" stop-opacity="${ha*0.85}"/>
      <stop offset="0.75" stop-color="${C.haloLilac}" stop-opacity="${ha*0.55}"/>
      <stop offset="1" stop-color="${C.haloLilac}" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="${id}g" x1="30" y1="25" x2="70" y2="90" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="${C.mintGlass}"/><stop offset="1" stop-color="${C.mintLight}"/></linearGradient>
    <linearGradient id="${id}l" x1="50" y1="57" x2="50" y2="92" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="${C.mint}"/><stop offset="1" stop-color="${C.mintDeep}"/></linearGradient>
    <clipPath id="${id}c"><path d="${body}"/></clipPath>
  </defs>
  <circle cx="50" cy="56" r="${haloR}" fill="url(#${id}h)"/>
  <ellipse cx="50" cy="93.5" rx="20" ry="2" fill="${C.mintLine}" opacity="0.18"/>
  <g transform="translate(0 ${bob.toFixed(2)})">
  <path d="${body}" fill="url(#${id}g)"/>`;
  let w = 'M0 57';
  for (let x=0; x<=100; x+=2) w += ` L${x} ${(57+Math.sin(x/7+t*2.6)*1.4).toFixed(2)}`;
  w += ' L100 100 L0 100 Z';
  s += `<path d="${w}" fill="url(#${id}l)" clip-path="url(#${id}c)"/>`;
  const count = thinking ? 7 : 3, speed = thinking ? 0.55 : 0.16;
  for (let i=0;i<count;i++){
    const phase = ((t*speed + i/count) % 1 + 1) % 1;
    const y = 80 - phase*82;
    const r = (1.4 + ((i*7)%5)*0.3) * (thinking?1.15:1);
    const sway = Math.sin(phase*Math.PI*3 + i*1.7) * (y<42 ? 3.2 : 9);
    const fade = phase>0.82 ? Math.max(0,1-(phase-0.82)/0.18) : Math.min(1, phase/0.08);
    s += `<circle cx="${(50+sway).toFixed(2)}" cy="${y.toFixed(2)}" r="${r.toFixed(2)}" fill="#fff" fill-opacity="${(0.85*fade).toFixed(2)}" stroke="${C.mintLine}" stroke-opacity="${(0.55*fade).toFixed(2)}" stroke-width="0.6"/>`;
  }
  s += `<path d="${body}" fill="none" stroke="${C.mintLine}" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round"/>
  <rect x="37" y="15" width="26" height="7" rx="3.5" fill="${C.mintLight}" stroke="${C.mintLine}" stroke-width="2"/>
  <path d="M29 78 L36.5 64" stroke="#fff" stroke-opacity="0.75" stroke-width="2.6" stroke-linecap="round"/>
  <ellipse cx="45.2" cy="30.5" rx="1.2" ry="4.5" fill="#fff" fill-opacity="0.7"/>
  <ellipse cx="32.5" cy="78.7" rx="4.2" ry="2.2" fill="${C.blush}" fill-opacity="0.75"/>
  <ellipse cx="67.5" cy="78.7" rx="4.2" ry="2.2" fill="${C.blush}" fill-opacity="0.75"/>`;
  if (research) {
    s += `<path d="M24.5 ${eyeY-1} L75.5 ${eyeY-1}" stroke="#37414A" stroke-opacity="0.9" stroke-width="3.2" stroke-linecap="round"/>`;
    for (const ex of [eyeL, eyeR]) {
      s += `<circle cx="${ex}" cy="${eyeY}" r="7.6" fill="#E4F6FF" fill-opacity="0.75" stroke="#37414A" stroke-width="2.4"/>
      <path d="M${ex-4.7} ${eyeY-1.7} Q${ex-3.9} ${eyeY-3.9} ${ex-1.7} ${eyeY-4.7}" fill="none" stroke="#fff" stroke-opacity="0.95" stroke-width="1.4" stroke-linecap="round"/>`;
    }
  }
  const eyeColor = research ? C.mintLine : '#fff';
  if (noticed) {
    for (const ex of [eyeL, eyeR]) s += `<ellipse cx="${ex}" cy="${eyeY}" rx="2.8" ry="3.2" fill="#24493A"/><circle cx="${ex-0.5}" cy="${eyeY-1.5}" r="0.9" fill="#fff"/>`;
    s += `<circle cx="50" cy="78.1" r="1.6" fill="none" stroke="#24493A" stroke-width="1.3"/>`;
  } else if (mood==='needsAccess') {
    for (const ex of [eyeL, eyeR]) s += `<path d="M${ex-3.6} ${eyeY} L${ex+3.6} ${eyeY}" stroke="${eyeColor}" stroke-width="2.6" stroke-linecap="round"/>`;
  } else {
    for (const ex of [eyeL, eyeR]) {
      const d = `M${ex-4.2} ${eyeY+2.2} L${ex} ${eyeY-2.4} L${ex+4.2} ${eyeY+2.2}`;
      if (!research) s += `<path d="${d}" fill="none" stroke="${C.mintLine}" stroke-opacity="0.35" stroke-width="4.2" stroke-linecap="round" stroke-linejoin="round"/>`;
      s += `<path d="${d}" fill="none" stroke="${eyeColor}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>`;
    }
  }
  s += `</g>`;
  if (mood==='needsAccess') s += `<circle cx="77" cy="21" r="7" fill="${C.red}" stroke="#fff" stroke-width="1.5"/><text x="77" y="24.6" font-family="Arial" font-weight="900" font-size="10" fill="#fff" text-anchor="middle">!</text>`;
  return s + `</svg>`;
}
if (typeof module !== 'undefined') module.exports = { buddySVG };

// App icon: a field-journal tile with the buddy on graph paper (macOS 824/1024 grid).
function iconSVG(px) {
  let grid = '';
  for (let v = 112; v <= 912; v += 40) grid += `<path d="M${v} 100V924M100 ${v}H924" stroke="#506b39" stroke-opacity="0.08" stroke-width="2"/>`;
  const inner = buddySVG({mood:'idle', research:false, t:0.4, size:640, id:'ic'})
    .replace('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="640" height="640">','<svg x="192" y="150" viewBox="0 0 100 100" width="640" height="640">');
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="${px}" height="${px}">
  <defs>
    <linearGradient id="tile" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F8F3E6"/><stop offset="1" stop-color="#EDE2CA"/></linearGradient>
    <clipPath id="sq"><rect x="100" y="100" width="824" height="824" rx="186"/></clipPath>
    <filter id="sh" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="10" stdDeviation="12" flood-color="#000" flood-opacity="0.28"/></filter>
  </defs>
  <rect x="100" y="100" width="824" height="824" rx="186" fill="url(#tile)" filter="url(#sh)"/>
  <g clip-path="url(#sq)">${grid}
    <path d="M100 800H924" stroke="#24211b" stroke-opacity="0.5" stroke-width="3"/>
    <text x="512" y="868" text-anchor="middle" font-family="Courier, monospace" font-size="44" fill="#776f60" letter-spacing="4">FIG. 1</text>
  </g>
  ${inner}
  <rect x="100" y="100" width="824" height="824" rx="186" fill="none" stroke="#24211b" stroke-opacity="0.18" stroke-width="3"/>
</svg>`;
}
if (typeof module !== 'undefined') module.exports = { buddySVG, iconSVG };
