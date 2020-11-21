local Q7Util = {}

function Q7Util.enc_delta_slow(enc_d, value_delta, min, max, speed)
    speed = speed or 0.15
    -- print("enc_d: "..enc_d.." value_delta: "..value_delta.." min: "..min.." max: "..max.." speed: "..speed)
    value_delta = util.clamp(value_delta + util.clamp(enc_d,-1, 1) * speed, min, max)

    return value_delta, util.round(value_delta)
end

function Q7Util.draw_reset_font()
    screen.font_face(1)
    screen.font_size(8)
end

function Q7Util.sign(n)
    return n > 0 and 1
        or  n < 0 and -1
        or  0
end

return Q7Util