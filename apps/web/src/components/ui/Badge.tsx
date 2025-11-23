import { HTMLAttributes, forwardRef } from "react";
import { cn } from "./Button";

interface BadgeProps extends HTMLAttributes<HTMLDivElement> {
    variant?: "default" | "secondary" | "outline" | "success";
}

export const Badge = forwardRef<HTMLDivElement, BadgeProps>(
    ({ className, variant = "default", ...props }, ref) => {
        return (
            <div
                ref={ref}
                className={cn(
                    "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2",
                    {
                        "border-transparent bg-primary text-primary-foreground shadow hover:bg-primary/80":
                            variant === "default",
                        "border-transparent bg-surface-active text-white hover:bg-surface-active/80":
                            variant === "secondary",
                        "text-white border-white/20": variant === "outline",
                        "border-transparent bg-green-500/20 text-green-400": variant === "success",
                    },
                    className
                )}
                {...props}
            />
        );
    }
);
Badge.displayName = "Badge";
