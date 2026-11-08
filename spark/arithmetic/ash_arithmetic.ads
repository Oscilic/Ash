with Interfaces;
use type Interfaces.Unsigned_64;

package Ash_Arithmetic
  with SPARK_Mode
is
   subtype U64 is Interfaces.Unsigned_64;

   type Division_Result is record
      Quotient  : U64;
      Remainder : U64;
   end record;

   function Divide_Unsigned
     (Numerator   : U64;
      Denominator : U64) return Division_Result
   with
      Pre => Denominator /= 0,
      Post =>
        Divide_Unsigned'Result.Remainder < Denominator;

end Ash_Arithmetic;