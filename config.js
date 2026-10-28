// À remplir avec les valeurs de VOTRE projet Supabase (Project Settings > API). La clé "anon" est publique par conception.
window.CFG={url:'https://xgzdgizwjdlgnmrurekp.supabase.co',key:'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhnemRnaXp3amRsZ25tcnVyZWtwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMxMzkwMDAsImV4cCI6MjEwODcxNTAwMH0.7Fa1U6IWCt7YawIMWpR9NCH_DTREjV0r0G9sK2vlXO8',domain:'mikoenglish.app'};
window.sb=supabase.createClient(CFG.url,CFG.key);
window.normPhone=p=>{let d=String(p).replace(/\D/g,'');if(d.startsWith('00241'))d=d.slice(5);else if(d.startsWith('241')&&d.length>9)d=d.slice(3);return d};
window.emailOf=p=>normPhone(p)+'@'+CFG.domain;
