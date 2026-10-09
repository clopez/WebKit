class C {
    #m() { return 1; }
    static f(o, n) {
        let x = n;
        if (o)
            x = o;
        if (o)
            return x.#m();
        return 0;
    }
}
noInline(C.f);

const objects = [];
for (let k = 0; k < 8; k++) {
    const c = new C();
    c["p" + k] = k;
    objects.push(c);
}
let sum = 0;
for (let i = 0; i < 200000; i++) {
    sum += C.f(objects[i & 7], i);
    sum += C.f(null, i + 0.5);
}
if (sum !== 200000)
    throw new Error("bad sum " + sum);
