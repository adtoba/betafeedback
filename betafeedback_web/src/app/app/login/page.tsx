import { redirect } from "next/navigation";

/** Web dashboard login removed — sign in on the mobile app. */
export default function AppLoginRedirect() {
  redirect("/#download");
}
