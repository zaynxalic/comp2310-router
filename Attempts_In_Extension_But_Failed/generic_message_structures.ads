--
--  Framework: Uwe R. Zimmer, Australia, 2015
--

with Ada.Strings.Bounded;           use Ada.Strings.Bounded;
with Generic_Routers_Configuration;
with Ada.Containers.Vectors;
with Queue_Pack_Protected_Generic;

generic
   with package Routers_Configuration is new Generic_Routers_Configuration (<>);

package Generic_Message_Structures is

   use Routers_Configuration;

   package Message_Strings is new Generic_Bounded_Length (Max => 80);
   use Message_Strings;

   package Natural_Vectors is new Ada.Containers.Vectors (
                                                          Element_Type => Natural,
                                                          Index_Type => Positive);
   use Natural_Vectors;
   -- using Ada vector

   subtype The_Core_Message is Bounded_String;

   type Messages_Client is record
      Destination : Router_Range;
      The_Message : The_Core_Message;
   end record;

   type Messages_Mailbox is record
      Sender      : Router_Range     := Router_Range'Invalid_Value;
      The_Message : The_Core_Message := Message_Strings.To_Bounded_String ("");
      Hop_Counter : Natural          := 0;
   end record;

   -- Leave anything above this line as it will be used by the testing framework
   -- to communicate with your router.
   --  Add one or multiple more messages formats here ..
   type Byte is mod 512;

   package Mail_Q is new Queue_Pack_Protected_Generic (Element => Messages_Mailbox,
                                                              Index => Byte);
   use Mail_Q;

   type MailBox_Q is new Mail_Q.Protected_Queue;
   -- implement the queue package

   type Array_Start_End_Node is array (Positive range <>) of Router_Range;

   type Arr_Router_Available is array (Positive range <>) of Boolean;
   -- check if the router is available

   Big_Number : constant Positive := Positive'Last;

   type Path_Hop is record
      Start_End_Vector : Natural_Vectors.Vector := Empty_Vector;
      Hop_Counter : Natural := Big_Number;
   end record;

   type Arr_Path_Hop is array (Positive range <>) of Path_Hop;

   type Inter_Sent_Messages is record
      Start_End_Node : Array_Start_End_Node (1 .. 2) := (others => Router_Range'Invalid_Value);
      Hop_Counter    : Natural                       := 0;
      Array_Path_Hop : Arr_Path_Hop  (1 .. Positive (Router_Range'Last));
      Array_Router_Available : Arr_Router_Available (1 .. Positive (Router_Range'Last)) := (others => True);
   end record;

   -- inter router message

   type Inter_Received_Messages is record
      Array_Path_Hop : Arr_Path_Hop  (1 .. Positive (Router_Range'Last));
      Array_Router_Available : Arr_Router_Available (1 .. Positive (Router_Range'Last)) := (others => True);
   end record;

   -- receive the message

   type Message_To_Neightbour is record
      Sender : Router_Range          := Router_Range'Invalid_Value;
      Destination : Router_Range     := Router_Range'Invalid_Value;
      Hop_Counter : Natural          := 0;
      The_Message : The_Core_Message := Message_Strings.To_Bounded_String ("");
   end record;
   -- Message Forward
end Generic_Message_Structures;
