import { Settings, Sparkles } from "lucide-react";
import { Button } from "./ui/Button";
import { motion } from "framer-motion";

interface HeaderProps {
    activeTab: "store" | "library";
    onTabChange: (tab: "store" | "library") => void;
    onOpenSettings: () => void;
}

export function Header({ activeTab, onTabChange, onOpenSettings }: HeaderProps) {
    return (
        <header className="fixed top-0 left-0 right-0 z-40 border-b border-white/5 bg-background/80 backdrop-blur-xl">
            <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
                <div className="flex items-center gap-2">
                    <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary/20 text-primary">
                        <Sparkles className="h-5 w-5" />
                    </div>
                    <span className="text-lg font-bold tracking-tight text-white">Storytelling</span>
                </div>

                <nav className="relative flex items-center rounded-full bg-surface p-1">
                    <button
                        onClick={() => onTabChange("store")}
                        className={`relative z-10 px-4 py-1.5 text-sm font-medium transition-colors ${activeTab === "store" ? "text-white" : "text-muted-foreground hover:text-white"
                            }`}
                    >
                        書城
                        {activeTab === "store" && (
                            <motion.div
                                layoutId="activeTab"
                                className="absolute inset-0 -z-10 rounded-full bg-surface-active"
                                transition={{ type: "spring", bounce: 0.2, duration: 0.6 }}
                            />
                        )}
                    </button>
                    <button
                        onClick={() => onTabChange("library")}
                        className={`relative z-10 px-4 py-1.5 text-sm font-medium transition-colors ${activeTab === "library" ? "text-white" : "text-muted-foreground hover:text-white"
                            }`}
                    >
                        書庫
                        {activeTab === "library" && (
                            <motion.div
                                layoutId="activeTab"
                                className="absolute inset-0 -z-10 rounded-full bg-surface-active"
                                transition={{ type: "spring", bounce: 0.2, duration: 0.6 }}
                            />
                        )}
                    </button>
                </nav>

                <Button variant="ghost" size="icon" onClick={onOpenSettings}>
                    <Settings className="h-5 w-5" />
                </Button>
            </div>
        </header>
    );
}
