String.prototype.capitalize = function() {
    return this.charAt(0).toUpperCase() + this.slice(1);
}

Object.defineProperty(Object.prototype, 'keys_length', {
    enumerable:false,
    value:function() {
        var size = 0, key;
        for (key in this) {
            if (this.hasOwnProperty(key)) size++;
        }
        return size;
    }
})

Array.max = function( array ){
    return Math.max.apply( Math, array );
};
Array.min = function( array ){
    return Math.min.apply( Math, array );
};