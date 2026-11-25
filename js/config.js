// Configuração central do Bolos & Gestão
// Use uma única instância Supabase para evitar conflitos de Auth.
window.BOLOS_CONFIG={SUPABASE_URL:"https://hqzxyjebdpblksigdede.supabase.co",SUPABASE_ANON_KEY:"sb_publishable_5481pNz72tLeTNPuaOCoiw_qn0Skodu"};
(()=>{
  if(window.__BG_CONFIG_V11_STARTED)return;window.__BG_CONFIG_V11_STARTED=true;
  const memory={};
  window.BOLOS_SAFE_STORAGE={
    get(key){try{return localStorage.getItem(key)}catch{return memory[key]??null}},
    set(key,value){try{localStorage.setItem(key,value)}catch{} memory[key]=String(value)},
    remove(key){try{localStorage.removeItem(key)}catch{} delete memory[key]}
  };
  if(window.supabase?.createClient&&!window.BOLOS_DB){
    const safeStorage={
      getItem(key){try{const v=localStorage.getItem(key);if(v!==null)return v}catch{}return memory['auth:'+key]??null},
      setItem(key,value){try{localStorage.setItem(key,value)}catch{}memory['auth:'+key]=String(value)},
      removeItem(key){try{localStorage.removeItem(key)}catch{}delete memory['auth:'+key]}
    };
    window.BOLOS_DB=window.supabase.createClient(window.BOLOS_CONFIG.SUPABASE_URL,window.BOLOS_CONFIG.SUPABASE_ANON_KEY,{auth:{storage:safeStorage,persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
  }
})();
