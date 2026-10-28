// Geometry checks complement native screenshots; they do not measure font glyphs.
const assert = require('node:assert/strict');
module.exports = function checkLayout(spec, width, height) {
  const widgets = [];
  for (const match of spec.matchAll(/(button_exit|button|hypertext|dropdown|item_image|image|label|textarea)\[((?:\\.|[^\]])*)\]/g)) {
    const fields = match[2].split(';');
    if(match[1]==='label' && fields.length<3) continue;
    const [x,y] = fields[0].split(',').map(Number);
    const [w,h] = fields[1].split(',').map(Number);
    assert([x,y,w,h].every(Number.isFinite), `Invalid dimensions: ${match[0]}`);
    assert(x>=0 && y>=0 && x+w<=width+.001 && y+h<=height+.001, `Outside form: ${match[0]}`);
    widgets.push({x,y,w,h,type:match[1],slot:match[1]==='image' && fields[2]==='everforge_ui_slot.png',raw:match[0]});
  }
  const contains = (a,b) => b.x>=a.x-.001 && b.y>=a.y-.001 && b.x+b.w<=a.x+a.w+.001 && b.y+b.h<=a.y+a.h+.001;
  for(let i=0;i<widgets.length;i++) for(let j=i+1;j<widgets.length;j++) {
    const a=widgets[i], b=widgets[j];
    const overlap=Math.min(a.x+a.w,b.x+b.w)-Math.max(a.x,b.x)>.002 && Math.min(a.y+a.h,b.y+b.h)-Math.max(a.y,b.y)>.002;
    if(!overlap) continue;
    if((a.slot && b.type==='item_image' && contains(a,b)) || (b.slot && a.type==='item_image' && contains(b,a))) continue;
    assert.fail(`Overlapping foreground widgets: ${a.raw} / ${b.raw}`);
  }
  const slots=widgets.filter(w=>w.slot);
  assert([0,4,9].includes(slots.length),`Incomplete recipe grid: ${slots.length} cells`);
  return widgets.length;
};
