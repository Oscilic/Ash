with Ada.Text_IO;
with Interfaces;
with Ash_Arithmetic;

procedure Test_Arithmetic is
   use type Interfaces.Unsigned_64;

   subtype U64 is Interfaces.Unsigned_64;

   procedure Check
     (N, D, Expected_Q, Expected_R : U64)
   is
      Result : constant Ash_Arithmetic.Division_Result :=
        Ash_Arithmetic.Divide_Unsigned (N, D);
   begin
      if Result.Quotient /= Expected_Q
        or else Result.Remainder /= Expected_R
      then
         raise Program_Error with "Arithmetic test failed";
      end if;

      Ada.Text_IO.Put_Line ("PASS");
   end Check;
procedure Check_Against_Native (N, D : U64) is
   Result : constant Ash_Arithmetic.Division_Result :=
     Ash_Arithmetic.Divide_Unsigned (N, D);
begin
   if Result.Quotient /= N / D
     or else Result.Remainder /= N rem D
   then
      raise Program_Error with "Division mismatch";
   end if;
end Check_Against_Native;
begin
   Check (120, 8, 15, 0);
   Check (100, 7, 14, 2);
   Check (0, 5, 0, 0);
   Check (U64'Last, 3, 6148914691236517205, 0);
   Check (U64'Last, 7, 2635249153387078802, 1);
   Check (U64'Last, 10, 1844674407370955161, 5);

   Ada.Text_IO.Put_Line ("All arithmetic tests passed.");
   for N in U64 range 0 .. 255 loop
   for D in U64 range 1 .. 255 loop
      Check_Against_Native (N, D);
   end loop;
end loop;

Check_Against_Native (U64'Last, 1);
Check_Against_Native (U64'Last, 3);
Check_Against_Native (U64'Last, 7);
Check_Against_Native (U64'Last, 10);
Check_Against_Native (U64'Last, 2 ** 63);
Check_Against_Native (U64'Last, U64'Last);

Ada.Text_IO.Put_Line
  ("65,280 additional arithmetic tests passed.");
end Test_Arithmetic;