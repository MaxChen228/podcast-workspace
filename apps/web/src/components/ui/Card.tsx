import { HTMLAttributes, forwardRef } from "react";
import { cn } from "./Button";

export const Card = forwardRef<HTMLDivElement, HTMLAttributes<HTMLDivElement>>(
    ({ className, ...props }, ref) => {
        return (
            <div
                ref={ref}
                className={cn(
                    "rounded-xl border border-white/5 bg-surface/50 p-4 text-white shadow-sm backdrop-blur-sm transition-all hover:bg-surface/80",
                    className
                )}
                {...props}
            />
        );
    }
);
Card.displayName = "Card";

export const CardHeader = forwardRef<HTMLDivElement, HTMLAttributes<HTMLDivElement>>(
    ({ className, ...props }, ref) => {
        return <div ref={ref} className={cn("flex flex-col space-y-1.5 p-2", className)} {...props} />;
    }
);
CardHeader.displayName = "CardHeader";

export const CardTitle = forwardRef<HTMLParagraphElement, HTMLAttributes<HTMLHeadingElement>>(
    ({ className, ...props }, ref) => {
        return (
            <h3
                ref={ref}
                className={cn("text-lg font-semibold leading-none tracking-tight", className)}
                {...props}
            />
        );
    }
);
CardTitle.displayName = "CardTitle";

export const CardContent = forwardRef<HTMLDivElement, HTMLAttributes<HTMLDivElement>>(
    ({ className, ...props }, ref) => {
        return <div ref={ref} className={cn("p-2 pt-0", className)} {...props} />;
    }
);
CardContent.displayName = "CardContent";
