import { uniqueId } from 'lodash';
import { useState } from 'react';
// types
import type { ChangeEvent, ReactNode } from 'react';

type Props = {
  checked: boolean;
  description?: ReactNode;
  label: ReactNode;
  onChange: (ev: ChangeEvent) => void;
  styles?: string[];
  tile?: boolean;
  value?: string;
};

export default function Checkbox({
  checked,
  description,
  label,
  onChange,
  styles = [],
  tile = false,
  value,
}: Props) {
  const [id] = useState(uniqueId('checkbox-'));
  return (
    <div
      className={`usa-checkbox ${styles.join(' ')}`}
      style={{ backgroundColor: 'inherit' }}
    >
      <input
        className={`usa-checkbox__input ${tile && 'usa-checkbox__input--tile'}`}
        id={id}
        type="checkbox"
        value={value}
        checked={checked}
        onChange={onChange}
      />
      <label className="usa-checkbox__label" htmlFor={id}>
        {label}
        {description && (
          <span className="usa-checkbox__label-description">{description}</span>
        )}
      </label>
    </div>
  );
}