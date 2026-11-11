with Interfaces;
use type Interfaces.Unsigned_64;

with Ash_Arithmetic_Lemmas;

package body Ash_Arithmetic_Reference
   with SPARK_Mode
is
   function Divide (Numerator : U64; Denominator : U64) return Division_Result
   is
      Quotient  : U64 := 0;
      Remainder : U64 := 0;
      Bit_Value : U64;
      Gap       : U64;
   begin

      for I in reverse 0 .. 63 loop

         -- Incorporamos espacio para el nuevo bit del cociente.
         Quotient := Interfaces.Shift_Left (Quotient, 1);

         -- Extraemos el siguiente bit del numerador.
         Bit_Value := Interfaces.Shift_Right (Numerator, I) and 1;

         -- Distancia entre el denominador y el resto.
         Gap := Denominator - Remainder;

         Ash_Arithmetic_Lemmas.Check_Gap (Remainder, Denominator);

         if Remainder >= Gap then

            Ash_Arithmetic_Lemmas.Check_Subtract_Branch
               (Remainder, Denominator, Bit_Value);

            Remainder := (Remainder - Gap) + Bit_Value;

            Quotient := Quotient or 1;

         elsif Bit_Value = 1 and then Remainder = Gap - 1 then

            Remainder := 0;
            Quotient := Quotient or 1;

         else

            Ash_Arithmetic_Lemmas.Check_No_Subtract_Branch
               (Remainder, Denominator, Bit_Value);

            Remainder := Interfaces.Shift_Left (Remainder, 1) or Bit_Value;

         end if;

         pragma Loop_Invariant (Remainder < Denominator);

         pragma
            Loop_Invariant
               (Quotient = Interfaces.Shift_Right (Numerator, I) / Denominator);

         pragma
            Loop_Invariant
               (Remainder = Interfaces.Shift_Right (Numerator, I) rem Denominator);

      end loop;

      return (Quotient => Quotient, Remainder => Remainder);

   end Divide;

end Ash_Arithmetic_Reference;
