from playwright.sync_api import sync_playwright
import os
here=os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(here,"icon-src"),exist_ok=True)
with sync_playwright() as p:
    b=p.chromium.launch(executable_path="/usr/bin/google-chrome",args=["--no-sandbox","--allow-file-access-from-files"])
    pg=b.new_page(viewport={"width":1300,"height":900},device_scale_factor=2)
    pg.goto("file://"+here+"/previews.html"); pg.wait_for_timeout(1200)
    for sel,name in [("#plate","preview-buddy-states.png"),("#menubar","preview-buddy-menubar.png"),("#pop","preview-popover.png"),("#doc","preview-explanation-card.png"),("#states2","preview-card-loading-error.png")]:
        pg.locator(sel).screenshot(path=os.path.join(here,name)); print(name)
    # Large renders for the app icon
    for size in [16,32,64,128,256,512,1024]:
        pg2=b.new_page(viewport={"width":size,"height":size},device_scale_factor=1)
        js=open(os.path.join(here,"buddy.js")).read()
        pg2.set_content('<html><body style="margin:0;background:transparent"><div id=i style="line-height:0"></div><script>'+js+'</script><script>document.getElementById("i").innerHTML=iconSVG('+str(size)+')</script></body></html>')
        pg2.wait_for_timeout(150)
        pg2.screenshot(path=os.path.join(here,"icon-src",f"icon_{size}.png"),omit_background=True)
        pg2.close()
    b.close()
