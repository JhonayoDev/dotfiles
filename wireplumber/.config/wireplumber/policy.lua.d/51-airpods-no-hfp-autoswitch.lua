-- Evita que WirePlumber cambie a perfil HFP (headset) cuando una app pide
-- microfono: ese cambio desmonta el transporte A2DP y a veces no vuelve
-- (a2dp_suspend SEP in bad state / getpeername: Transport endpoint is not
-- connected), dejando el audio "reproduciendo" sin sonido hasta reconectar.
-- Costo: para usar el micro de los AirPods hay que cambiar el perfil a mano
-- (pactl set-card-profile bluez_card.<MAC> headset-head-unit).
bluetooth_policy.policy["media-role.use-headset-profile"] = false
